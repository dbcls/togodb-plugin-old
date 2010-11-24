# -*- coding: cp932 -*-
require 'ftools'                # for File.copy
require 'csv'
require 'fileutils'

class TogodbImportController < ApplicationController
  layout "togodb/import"
  helper "togodb/application"
  helper "togodb"

  include ActionView::Helpers::NumberHelper
  include Togodb::TemporaryWorkspace
  include Togodb::Auths::System
  include Togodb::Utils::Encoding

  before_filter :login_required, :except => ['handle']
  skip_before_filter :verify_authenticity_token ,:only=>['handle']  #3
  before_filter :prepare_variables

  delegate :transaction, :to=>"ActiveRecord::Base"

  class InvalidTableName  < RuntimeError; end
  class InvalidColumnName < RuntimeError; end
  class NotNamedYet       < Togodb::ExpectedError; end
  class NotUploadedYet    < Togodb::ExpectedError; end
  class DataNotFound      < Togodb::ExpectedError; end

private
  def prepare_variables
    @steps = ActiveSupport::OrderedHash.new #3
    @steps[:name] = as_("Database name")
    @steps[:upload] = as_("File upload")
#    @steps << [:convert, as_("convert character code")]
    @steps[:schema] = as_("Header line")
    @steps[:columns] = as_("Create table")
    @steps[:import] = as_("Import data")

    @step_action_name = @action_name  # for _step.rhtml

    if local_session[:table_id]
      @table = Togodb::Table.find(local_session[:table_id]) rescue
        (local_session[:table_id] = nil)
    end

    @sjis = uploaded_file(:sjis)
    @utf8 = uploaded_file(:utf8)

    @nkf_option = "-w -x -d --no-best-fit-chars"

    if controller_name == "togodb_reimport"
      @html_title = "Re-import"
    else
      @html_title = "Import"
    end

    return true
  end

  def local_session
    session_index = params[:controller] || "unknown"
    session[session_index] ||= { }
    session[session_index]
  end

  def uploaded_file(postfix = nil)
    id = @table ? @table.id : "unknown"
    postfix = ".#{postfix}" if postfix
    workspace_path + "togodb_table_#{id}.csv#{postfix}"
  end

  def head_entries
    local_session[:head_entries] ||= scan_csv
  end

  def csv_reader
    raise NotNamedYet unless @table
    #-->raise NotUploadedYet, as_("No file is uploaded") unless @utf8.exist?
    raise NotUploadedYet, as_("No file is uploaded") unless @sjis.exist?
    # convert to File object first because CSV gets wrong with pathname object

    if @utf8.exist?
      return CSV::Reader.create(File.open(@utf8.to_s, 'r'))
    else
      return CSV::Reader.create(File.open(@sjis.to_s, 'r'))
    end
  end

  def scan_csv
    # create
    entries = []
    csv_reader.each_with_index do |row, i|
      entries << row.map {|s| NKF.nkf(@nkf_option, s.to_s)}
      break if i == 2           # we need first three rows at most
    end

    header = entries.first      # header or one data should be exist
    raise Togodb::DataNotFound if header.blank?

    local_session[:column_size]  = header.size
    local_session[:head_entries] = entries

    return entries
  end

  def rescue_action(err)
    case err
    when NotNamedYet
      redirect_to :action=>"name"
      return
    when InvalidTableName
      render :action=>"name"
      return
    when InvalidColumnName
      render :action=>"columns"
      return
    when NotUploadedYet
      @step_action_name = "upload"
      @message = as_("No files are uploaded")
      render :inline=>"", :layout=>true
      return
    when Togodb::ExpectedError
      if err.message == err.class.name
        message = err.class.name.demodulize
      else
        message = err.message
      end
      unless request.xhr?
        @message = message
        render :inline=>"", :layout=>true
        return
      end
    else
      Togodb.action_error(err, params)
      message = "[%s] %s" % [err.class, err.message]
    end

    logger.debug message
    logger.debug err.backtrace.join("\n") rescue nil

    if request.xhr?
      @message = message
      render :update do |page|
        page[:message].replace_html oneline_message(@message, 'error')
      end
    else
      @message = message
      render :action=>"error"
    end
  end

  def worker_name
    :togodb_import_csv_worker
  end

  def current_worker
    local_session[worker_name]
  end

  def header?
    local_session[:header]
  end

  def valid_table_name_regexp
    /^[a-z][a-z0-9_]*$/
  end

  def guess_column_type_simply(name, data)
    return "string" if /name/ === name.to_s

    case data.to_s
    when /^-?\d+$/      then "integer"
    when /^-?\d*\.\d+$/ then "float"
    else
      "string"
    end
  end

  def guess_column_types(column_indexes = nil)
    Togodb::Utils::GuessColumnType.new(uploaded_file(:sjis), :header=>header?).execute(column_indexes)
#  rescue => err
#    Togodb.syslog(err)
#    return []
  end

  def valid_column_name?(name)
    /^[a-z][a-z0-9_]*$/ === name.to_s
  end

  def coerce_to_column_name(name)
    name = name.to_s.strip.underscore.gsub(/[\s_-]+/, '_')
    if valid_column_name?(name)
      name
    else
      @unknown_column_index = @unknown_column_index.to_i + 1
      "col#{@unknown_column_index}"
    end
  end

  def ensure_valid_columns
    @columns = @columns.sort_by(&:position)
    @samples = (header? ? head_entries[1] : head_entries[0]) || []

    used = {}
    @columns.each do |column|
      if column.name == "id"
        column[:column_name_error] = "invalid"
        flash.now[:error] = as_("'id' is reserved for primary key") if column.enabled?
      elsif !valid_column_name?(column.name)
        column[:column_name_error] = "invalid"
        flash.now[:error] ||= as_("'%s' is not valid for column name") % column.name if column.enabled?
      end

      if column.enabled?
        if used[column.name]
          column[:column_name_error] = "invalid"
          flash.now[:error] ||= as_("'%s' is already used") % column.name
        end
        used[column.name] = true
      end
    end

    if flash.now[:error]
      raise InvalidColumnName
    end
  end

  def reset_uploaded
    local_session.delete(:header)
    local_session.delete(:column_size)
    local_session.delete(:head_entries)
    @utf8.delete if @utf8.exist?
    @sjis.delete if @sjis.exist?
  end

  def create_utf8_file
    @utf8.open("w"){|f| f.print NKF.nkf(@nkf_option, @sjis.read)}
  end

  def create_record(model, record, row_id, valid_columns)
    return false if row_id == 0 and header?

    hash = {}
    record.each_with_index do |data, i|
      column = valid_columns[i] or next
      if !data.nil? && @in_encoding != Togodb::Utils::Encoding::NOCONV
        data = toutf8(data, @in_encoding) unless data.nil?
      end
      hash[column.name] = data
    end
    model.set_primary_key "id"
    model.create!(hash)

    true
  end

  def import_csv(drop_table = false)
    # first, decide character encoding
    @in_encoding = guess_encoding(@sjis.to_s)

    klass = @table.active_record
    if local_session[:column_names].blank?
      valid_columns = @table.columns.map{|c| c.enabled? ? c : nil}
    else
      valid_columns = []
      local_session[:column_names].each {|column_name|
        togodb_column = Togodb::Column.find(:first, :conditions => ['table_id = ? AND name = ?', @table.id, column_name])
        if togodb_column.enabled?
          valid_columns << togodb_column
        else
          valid_columns << nil
        end
      }
    end

    count = 0

    transaction do
      if drop_table
        @table.migrate :down # drop table
        @table.migrate       # create table
      end
      begin
        require 'csvscan'
        open(@sjis.to_s) {|io|
          i = 0
          CSVScan.scan(io) {|row|
            count += 1 if create_record(klass, row, i, valid_columns)
            i += 1
          }

          #@table.imported = false
          @table.save!
        }
      rescue LoadError => e
        csv_reader.each_with_index do |row, i|
          count += 1 if create_record(klass, row, i, valid_columns)
        end

        #@table.imported = false
        @table.save!
      end
    end

    count
  end

public
  def index
    redirect_to :action=>"name"
  end

  def name
    if !request.post?
      params[:table_name] = @table.name if @table
    end
    return unless request.post?

    table_name = params[:table_name].to_s.strip
    # first, check whether the given table name is valid or not

    if table_name !~ valid_table_name_regexp
      return flash.now[:error] = as_("Invalid table name")
    end

    # then, check confliction with existing tables
    if ActiveRecord::Base.connection.tables.include?(table_name)
      return flash.now[:error] = as_("The table '%s' already exists") % table_name
    end

    # lookup ruby classes whether the model class name conflicts or not
    begin
      model = Togodb::Table.new(:name=>table_name).class_name
      klass = model.constantize
      if klass.is_a?(Class) and klass < ActiveRecord::Base
        # ok. it seems re-importing
      else
        return flash.now[:error] = as_("'%s' conflicts with system name '%s'") % [table_name, model]
      end
    rescue NameError
      # no conflicts
    end

    # finally, find drafting one
    table = Togodb::Table.find_by_name(table_name)
    if table
      if table.imported?
        unless params[:continue]
          return flash.now[:error] = as_("The table '%s' already exists. You can drop it in Database Browser if you want.") % table_name
        end

        # continue the previous work
      else
        # you dropped table manually???
        table.destroy
        table = nil
      end
    end

    table ||= Togodb::Table.create!(:name=>table_name, :enabled=>false, :imported=>true)
    local_session[:table_id] = table.id

    # mark this user as an admin for this table
    Togodb::Role.instance(table, current_user).admin!

    redirect_to :action=>"upload"
  end

  def handle
    file_path = workspace_path + params[:instance]
    if params[:SolmetraUploader].to_s[0,6] == '#<File'
      copy_file(params[:SolmetraUploader].path, file_path)
    elsif params[:SolmetraUploader].respond_to?(:read)
      file_path.open('w') {|f| f.print params[:SolmetraUploader].read}
    end

    render :text => "OK:#{file_path}"
  end

  def upload
    if params[:solmetraUploaderInstance].nil?
      @instance_id = random_str
    end

    raise NotNamedYet unless @table
    return unless request.post?

    file_path = params[:solmetraUploaderData][params[:solmetraUploaderInstance]].split('|')[1]
    move_file(file_path, @sjis)
    #-->buffer = File.read(file_path)

#    case buffer = params[:file]
#    when String
      # nop
#    else
#      if buffer.respond_to?(:read)
#        buffer = buffer.read
#      else
#        raise "[BUG] we expect params[:file] is String or IO, but got [%s]" % buffer.class
#      end
#    end
#    reset_uploaded
    #-->@sjis.open("w+"){|f| f.print buffer}

    # convert
    #-->@nkf_option = "-w -x -d --no-best-fit-chars"
    #-->@utf8.open("w+"){|f| f.print NKF.nkf(@nkf_option, @sjis.read)}
    @table.columns.destroy_all

    flash[:notice] = as_("got 1 file") + " (%s)" % number_to_human_size(@sjis.size)
    redirect_to :action=>"schema"
  end

  def schema
    unless request.post?
      @head_entries = head_entries
      return
    end

    local_session[:header] = !!params[:header]
    redirect_to :action=>"columns"
  end

  def columns
    @step_action_name = "schema"
    raise Togodb::ExpectedError, "missing @table" unless @table

    unless @table.columns.size == local_session[:column_size]
      Togodb.logger.debug "generating columns for %s" % @table.name
      @table.columns.destroy_all
      if header?
        labels  = head_entries[0]
        headers = labels.map{|i| coerce_to_column_name(i)}
        samples = head_entries[1] || headers
      else
        headers = (1..local_session[:column_size]).map{|i| "col#{i}" }
        labels  = headers
        samples = head_entries[0]
      end

      types = guess_column_types

      local_session[:column_size].times do |i|
        name = coerce_to_column_name(headers[i])
        type = types[i] || guess_column_type_simply(headers[i], samples[i])
        text = (/^(string|text)$/ === type.to_s)
        attributes = {
          :name           => name,
          :label          => labels[i],
          :type           => type,
          :enabled        => true,
          :sanitize       => true,
          :position       => i + 1,
          :action_list    => (/name/ === name) || (i < 5),
          :action_show    => true,
          :action_search  => text,
          :action_luxury  => text,
          :list_disp_order => i < 5 ? i + 1 : nil,
          :show_disp_order => i + 1,
          :dl_column_order => i + 1
        }
        @table.columns.create(attributes)
      end
    end

    @columns = @table.columns(true)
    ensure_valid_columns
  end

  def create_table
    @step_action_name = "schema"
    return unless request.post?

    @columns = []
    # "23"=>{ "name"=>"id", "type"=>"integer", "label"=>"id"}
    params.each_pair do |id, hash|
      next unless /^\d+$/ === id.to_s
      column = Togodb::Column.find(id)
      hash["enabled"] = "0" unless hash.has_key?("enabled")
      hash[:type] = "string" if hash[:type] == "other"
      column.update_attributes!(hash)
      @columns << column
    end

    ensure_valid_columns

    @table.migrate :down
    @table.migrate

    flash[:notice] = as_("Created new table '%s'") % @table.name
    redirect_to :action=>"import"
  end

  def import
    csv_reader                  # should be exist
    return unless request.xhr?

    count = import_csv

    # mark this user as an admin for this table
    #Togodb::Role.instance(@table, current_user).admin!

    # finally drop disabled columns
    @table.columns.each do |column|
      column.destroy unless column.enabled?
    end

    flash[:notice] = as_("%d data were imported into '%s'") % [count, @table.name]


    @table1 = Togodb::Table.find_by_name(@table.name)
p    file = Togodb::Generators::Model.new(@table1, :confirm=>true)
    file.construct
p    file = Togodb::Generators::Controller.new(@table1, :confirm=>true)
    file.construct
    wsdlns =  "%s%s%s" % [request.protocol, request.host_with_port, request.request_uri.sub(/togodb.*$/, @table1.singular_name)]
            options = { :wsdl_namespace => wsdlns }
     file= Togodb::Generators::WebService.new(@table1, options)
    file.construct

    file = Togodb::Generators::Page.new(@table1)
    file.construct

    render :update do |page|
      page.redirect_to :action=>"done"
    end

    local_session.clear
  end

  def import_by_backgroundrb
    raise Togodb::ExpectedError, as_("No files are uploaded yet") unless @utf8.exist?
    return unless request.xhr?

    background_task

    render :update do |page|
      page.redirect_to :action=>"progress"
    end

  rescue DRb::DRbConnError => err
    #druby://localhost:22222 - #<Errno::ECONNREFUSED: 接続を拒否されました - connect(2)>
#    message = err.message
#    Togodb.syslog(:priority=>50, :message=>message)
    raise Togodb::ExpectedError, as_("cannot connect to BackgrounDRB")
  end

  def background_task
    args = {:utf8=>@utf8}
    local_session[worker_name] = MiddleMan.new_worker(:class => worker_name, :args=>args)
  end

  def done
    local_session.clear
  end

  def done_by_backgroundrb
    if current_worker
      @worker = MiddleMan.get_worker(current_worker)
      @estimate_result = render_to_string(:partial=>"estimate")
      MiddleMan.delete_worker(current_worker)
      local_session[worker_name] = nil
    end
  end

  def progress
    @worker = MiddleMan.get_worker(current_worker)
    if request.xhr?
      if @worker.error?
        render :update do |page|
          page.redirect_to :action=>"error"
        end
      else
        render :update do |page|
          page[:estimate].replace :partial=>"estimate"
          page.redirect_to( :action => 'done') if @worker.finished?
        end
      end
    end
  end

  def import_error
    @errors = Togodb::ImportError.find(:all, :order=>"created_at DESC", :limit=>1)
  end

  def errors
    if request.xhr?
      count   = [(params[:count].to_i rescue 1), 1].max
      start   = MiddleMan.get_worker(current_worker).start rescue 1.day.ago
      @errors = Togodb::ImportError.find(:all, :conditions=>["created_at >= ?", start],#"
                                       :order=>"created_at DESC", :limit=>count).reverse
      render :update do |page|
        page[:errors].replace_html :partial=>"errors"
      end
    else
      render :nothing=>true
    end
  end

  def random_str(length = 32)
    source = ("a".."z").to_a + ("A".."Z").to_a + (0..9).to_a + ["_"]
    key = ""
    length.times {key += source[rand(source.size)].to_s}

    key
  end

  def copy_file(src_file, dst_file)
    FileUtils.cp(src_file, dst_file)
    ##system("cp #{src_file} #{dst_file}")
  end

  def move_file(src_file, dst_file)
    ##File.rename(src_file, dst_file)
    FileUtils.mv(src_file, dst_file)
  end

  def copy_file0(src_file, dst_file)
    data_size = 1024 * 1024 # 1024k bytes
    open(dst_file, 'wb') {|dst|
      open(src_file, 'rb') {|src|
        while data = src.read(data_size)
          dst.write(data)
        end
      }
    }
  end
end

