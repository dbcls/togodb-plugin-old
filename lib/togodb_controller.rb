# -*- coding: utf-8 -*-
require 'cgi'

class TogodbController < ApplicationController
  layout  :select_layout ,:except => [:join_tables,:drop_throughs]
  helper  "togodb/application"
  helper  "togodb/admin"
  include Togodb::TemporaryWorkspace
  include Togodb::Auths::System

  before_filter :login_required, :except=>"login"

  delegate :transaction, :to=>"ActiveRecord::Base"

  active_scaffold "Togodb::Table" do |config|
    config.actions.exclude :create, :search
    config.columns = %w( name columns enabled )
    config.columns[:enabled].label = 'Status'
    config.list.sorting = {:name => :asc }
    config.list.label = as_("Database Browser")
    config.list.per_page = 1000000

    ######################################################################
    ### Table link

    config.action_links.add :scan, :label=>"Scan"
    config.action_links[:scan].page = true

    config.action_links.add :import, :label=>"Import"
    config.action_links[:import].page = true
    config.action_links[:import].controller = "togodb_import"
    config.action_links[:import].action = "name"

    ######################################################################
    ### Record links

    config.actions.exclude :update
  end

  active_scaffold_config.action_links.delete(:show)

  ######################################################################
  ### ActiveScaffold actions

  def show
    ensure_role :read
    render :action=>"show.rjs"
  end

  def create
    ensure_role :superuser
    super
  end

  def destroy
    ensure_role :superuser
    do_destroy
    redirect_to :action=>"index"
  end

  def update
    ensure_role :write
  end

  def page
    ensure_role :execute
    construct
    redirect_to :controller=>@record.singular_name
  end

  def scan
    ensure_role :superuser
    Togodb::Table.sync
    redirect_to :action=>"index"
  end

  ######################################################################
  ### Togodb actions

  def search_users
    ensure_role :execute

    login = params[:login].to_s.strip
    @user = Togodb::User.find(:first, :conditions=>["login = ?", login])
    render :update do |page|
      if @user
        @role = @record.role_for(@user) || Togodb::Role.new
        page[:user_role].replace_html :partial=>"user_role"
      else
        page[:user_role].replace_html "Unknown user"
      end
    end
  end

  def update_users
    ensure_role :admin

    # "id"=>"1", "user"=>"2", "login"=>"maiha"
    # "role"=>{"role_read"=>"1", "role_write"=>"1", "role_admin"=>"0"}
    @user = Togodb::User.find(params[:user])
    @role = Togodb::Role.instance(@record, @user)
    @role.update_attributes(params[:role])
    render :update do |page|
      page[:user_role].replace_html "Updated"
    end
  end

  def update_db_settings
    @record = Togodb::Table.find(params[:id])
    @record.update_attributes(params[:record])
    construct

    flash[:notice] = "Database settings changed successfully."

    render :partial => "tab_summary"
  end

  def update_columns
    ensure_role :admin

    # "records"=>{ "22"=>{ "label"=>"yomi", "showable"=>"1", ...} },
    # "primary_key" => "22"

    # validate
    error_messages = validate_column_settings
    unless error_messages.empty?
      error_message = '<span style="font-weight: bold; color: #FF0000;">Error:</span><br />' + error_messages.join('<br />')
      render :update do |page|
        page[:error].replace_html error_message
      end
      return
    end

    # boolean hack
    bools = Togodb::Column.columns.select{|c|c.type == :boolean}.map(&:name)

    transaction do
      params[:records].each_pair do |id, hash|
        bools.each{|key| hash[key] ||= false}
        hash[:primary_key] = (id == params[:primary_key]) if params.key?(:primary_key)
        hash[:record_name] = (id == params[:record_name]) if params.key?(:record_name)
        hash[:sorting] = (id == params[:sorting]) if params.key?(:sorting)
        hash[:enabled] = true     # all records should be enabled
        column = Togodb::Column.update(id, hash)
      end

      # throuths tables
      unless params[:throughs].nil?
        params[:throughs].each_pair do |id, hash|
          Togodb::Through.update(id, hash)
        end
      end

      @record.save!               # mark updated_at
    end

    @record.columns(true)       # force to reload
    construct

    render :action=>"show.rjs"
  end

  def add_column
    ensure_role :admin
    new_column = nil

    if (params[:column][:name].nil? || /\A\s*\z/ =~ params[:column][:name])
      flash.now[:error] = "Column name is not specified.";
      render :partial => 'tab_column'
      return
    end

    if (params[:column][:label].nil? || /\A\s*\z/ =~ params[:column][:label])
      params[:column][:label] = params[:column][:name]
    end

    # params[:column] => {:name => 'ColName', :type => 'ColType', :label => 'ColLabel'}
    begin
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.add_column @record.name, params[:column][:name], params[:column][:type].to_sym
        new_column = @record.columns.create(column_default_values(params[:column][:type]).merge(params[:column]))
      end

      if new_column.nil? || new_column.new_record?
        flash.now[:error] = "Error: column \"#{params[:column][:name]}\" is not added."
      else
        flash.now[:notice] = "Column \"#{params[:column][:name]}\" is added."
      end
    rescue => e
      flash.now[:error] = e.message
    end

    render :partial => 'tab_column'
  end

  def add_index
    ensure_role :admin
    begin
      ActiveRecord::Base.transaction do
        table = Togodb::Table.find(params[:id].to_i)
        params[:column_ids].each {|column_id, indexing|
          next unless indexing == "1"
          column = Togodb::Column.find(column_id.to_i)
          column.indexing = true
          column.save
          ActiveRecord::Base.connection.execute("CREATE INDEX #{table.name}_#{column.name}_index ON #{table.name} (#{column.name})")
        }
      end
      flash.now[:notice] = "Index added successfully."
    rescue => e
      flash.now[:error] = e.message
    end

    render :partial => 'tab_column'
  end

  def update_setting
    ensure_role :admin

    # "setting"=>{"page_footer"=>"", "page_header"=>"<h2>Kids</h2>", "html_title"=>"kids page", ...}
    transaction do
      @setting = @record.setting
      @setting.attributes = params[:setting]
      @setting.save!
      @record.save!               # mark updated_at
    end

    construct

    render :action=>"show.rjs"
  end

  def start_service
    set_service_to true
    construct
  end

  def stop_service
    set_service_to false
    # stop service but not erase codes
    # destruct
  end

  def download
    ensure_role :read

    # generate temporary file
    pathname = workspace_path + "#{@record.name}.csv"
    pathname.open("w+") do |file|
      Togodb::Utils::Exports::Table.new(@record).write_as(:csv, pathname)
    end

    # output
    send_file pathname.to_s, :filename => pathname.basename, :type => 'text/csv'
  end

  def web_service_settings
    @record = Togodb::Table.find(params[:id].to_i)
    @togodb_column = Togodb::Column.find(params[:column_id].to_i)
    render :partial => "web_service_settings"
  end

  def set_webservice
    ensure_role :admin
    begin
      togodb_column = Togodb::Column.find(params[:column_id].to_i)
      @record = togodb_column.table

      togodb_column.genbank_entry_text = params[:genbank_entry_text]
      togodb_column.genbank_entry_xml = params[:genbank_entry_xml]
      togodb_column.genbank_seq_fasta = params[:genbank_seq_fasta]
      togodb_column.pubmed_abstract = params[:pubmed_abstract]
      togodb_column.embl_entry_text = params[:embl_entry_text]
      togodb_column.embl_entry_xml = params[:embl_entry_xml]
      togodb_column.embl_seq_fasta = params[:embl_seq_fasta]
      togodb_column.ddbj_entry_text = params[:ddbj_entry_text]
      togodb_column.ddbj_entry_xml = params[:ddbj_entry_xml]
      togodb_column.ddbj_seq_fasta = params[:ddbj_seq_fasta]
      togodb_column.save
      flash.now[:notice] = "Successful set of Web services."
    rescue => e
      flash.now[:error] = e.message
    end
    render :partial => 'tab_column'
  end

  ######################################################################
  ### Control Panel

  def install_candidates
    files = install_files.map(&:test).flatten.compact
    render :update do |page|
      page[:install_candidates].replace_html :partial=>"install_candidates", :locals=>{:files=>files}
    end
  end

  def install
    construct

    render :update do |page|
      page[:install].replace_html :partial=>"updated"
    end
  end

  def uninstall
    ensure_role :admin

    name = Togodb::Table.find(params[:id]).name
   if Togodb::Through.find(:all,:conditions=>["table1=? OR table2=?",name,name]).size > 0

    render :update do |page|
      page[:drop_message].replace_html "there is through table cannot delete"
    end
     return
   end

    if params[:droptable]
      klass = @record.active_record
      klass.send :include, Migratable
      klass.migrate :down
    end
    destruct
    destroy
  end


  ######################################################################
  def drop_throughs
#    ensure_role :admin
    @drop_message = ""

    through = Togodb::Through.find(params[:id])

    begin
      ActiveRecord::Base.connection.execute "DROP TABLE #{through.name}"
    rescue
    end

    # drop file
    p pc = "app/models/#{through.name}.rb"
    ::File.unlink(pc) if  ::File.exist?(pc)
   name = through.name
    through.destroy


   name.split("_table")[1..2].each do |table_id|

    @table2 = Togodb::Table.find(table_id.to_i)
    file = Togodb::Generators::Model.new(@table2, :confirm=>true)
    file.construct
    file = Togodb::Generators::Controller.new(@table2, :confirm=>true)
    file.construct
    wsdlns =  "%s%s%s" % [request.protocol, request.host_with_port, request.request_uri.sub(/togodb.*$/, @table2.singular_name)]
            options = { :wsdl_namespace => wsdlns }
     file= Togodb::Generators::WebService.new(@table2, options)
    file.construct
   end

    @record = Togodb::Table.find(params[:record])
    render :update do |page|
      #page.alert("#{params[:id]} dropped!")
      page.replace_html "through_tables",:partial => "through_tables"
      page.replace_html "message", @drop_message
    end

  end

  ### Table join


  def join_tables
    if !params[:table_left] || !params[:table_right]
      @join_message = "input params error"
      return
    end

    @join_message = ""
    dbs = Array.new
    htable = Hash.new
    htable[params[:table_right][:id]]=params[:table_right]
    htable[params[:table_left][:id]]=params[:table_left]
    dbs << params[:table_right][:id]
    dbs << params[:table_left][:id]
    dbs.sort!

    @through =  Togodb::Through.find_by_name("through_table"+dbs.join("_table"))
    @through =  Togodb::Through.new() if !@through
    @through.name = "through_table"+dbs.join("_table")
    @through.table1  = htable[dbs[0]][:table]
    @through.column1 = htable[dbs[0]][:column]
    @through.table2  = htable[dbs[1]][:table]
    @through.column2 = htable[dbs[1]][:column]
    @through.save

    @through.create_table

    # update through model
    file = Togodb::Generators::Through.new(@through)
    file.construct

    # update table model
=begin
    @table = Togodb::Table.find_by_name(params[:table_left][:name])
p    file = Togodb::Generators::Model.new(@table, :confirm=>true)
    file.construct
p    file = Togodb::Generators::Controller.new(@table, :confirm=>true)
    file.construct
=end


    @table = Togodb::Table.find_by_name(@through.table1)
p    file = Togodb::Generators::Model.new(@table, :confirm=>true)
    file.construct
p    file = Togodb::Generators::Controller.new(@table, :confirm=>true)
    file.construct
    wsdlns =  "%s%s%s" % [request.protocol, request.host_with_port, request.request_uri.sub(/togodb.*$/, @table.singular_name)]
            options = { :wsdl_namespace => wsdlns }
     file= Togodb::Generators::WebService.new(@table, options)
    file.construct

    @table = Togodb::Table.find_by_name(@through.table2)
p    file = Togodb::Generators::Model.new(@table, :confirm=>true)
    file.construct
p    file = Togodb::Generators::Controller.new(@table, :confirm=>true)
    file.construct
    wsdlns =  "%s%s%s" % [request.protocol, request.host_with_port, request.request_uri.sub(/togodb.*$/, @table.singular_name)]
            options = { :wsdl_namespace => wsdlns }
     file= Togodb::Generators::WebService.new(@table, options)
    file.construct



    sql = "SELECT t1.id as #{@through.table1}_id,t2.id as #{@through.table2}_id "
    sql += "FROM #{@through.table1} AS t1, #{@through.table2} AS t2 "
    sql += "WHERE t1.#{@through.column1} = t2.#{@through.column2} "

    lines = Togodb::Table.find_by_sql(sql)
p "########TOTAL LINES###########"
p "Total:"+lines.size.to_s

    ratio = 0  # 進捗率
    progress = 0
#    render :update do |page|
      #page.alert("#{params[:id]} dropped!")

    lines.each do |line|
      progress += 1
p (progress*100/lines.size).to_s + "%"
      Object.const_get(@through.class_name).create(line.attributes)

#          page.replace_html "message", (progress*100/lines.size).to_s
#    end
  end
p "##############################"




=begin
    @columns = []
    # "23"=>{ "name"=>"id", "type"=>"integer", "label"=>"id"}
    @params[1]={"name"=>"id","type"=>"integer"}
    @params[2]={"name"=>@record.table1+"_id","type"=>"integer"}
    @params[3]={"name"=>@record.table2+"_id","type"=>"integer"}
    params.each_pair do |id, hash|
      column = Togodb::Column.find(id)
      @columns << column
    end

#    ensure_valid_columns

    @table.migrate :down
    @table.migrate
    # DB存在確認
    # ActiveRecord::Base.connection.tables.include?('togodb_tables')=end
=end


#@table= Togodb::Join.find(@record.id)

#    Togodb::Table.find_by_sql("select  t1.id as susi_id,t2.id as point_id from #{dbs[0]} as
# t1 ,#{dbs[1]} as t2 where t1.#{tableleft} = t2.namae")
 #   Togodb::Table.create!(:name=>"hoge")
 #   @join_message = dbleft+tableleft+dbright+tableright
    @record = Togodb::Table.find(params[:id])
  #  render :update do |page|
  #    page.replace_html "through_tables",:partial => "through_tables"
  #  end
  end

  def table_columns
    @record = Togodb::Table.find(params[:id][/\d+/].to_i)

    render :update do |page|
      #page.alert("#{params[:id]} dropped!")
      page.replace_html "table_#{params[:align]}_name", :partial => "table_name"
      page.replace_html "table_#{params[:align]}_columns", :partial => "table_columns" , :locals => {:align => params[:align]}
    end
  end

  ######################################################################
  # Metadata
  ######################################################################
  def show_metadata
    @record = Togodb::Table.find(params[:id])
    render :partial => 'togodb/tab_metadata'
  end

  def edit_metadata
    @record = Togodb::Table.find(params[:id])
    render :partial => 'togodb/tab_metadata_edit'
  end

  def load_taxonomy
    id = nil
    value = nil
    taxonomy_name = ''

    if params.key?(:taxonomy)
      id, value = params[:taxonomy].shift
    elsif params.key?(:new_taxonomy)
      id, value = params[:new_taxonomy].shift
    end

    unless value.nil?
      begin
        taxonomy = Togodb::NcbiTaxonomy.find(value['taxonomy_id'].to_i)
        taxonomy_name = taxonomy.name
      rescue => ex
        taxonomy_name = ''
      end
    end

    render :json => {:taxonomy_name => taxonomy_name}.to_json
  end

  def load_pubmed
    require 'open-uri'

    id = nil
    value = nil
    title = ''
    author = ''
    elem_name_prefix = nil

    if params.key?(:literature)
      id, value = params[:literature].shift
      elem_name_prefix = 'literature'
    elsif params.key?(:new_literature)
      id, value = params[:new_literature].shift
      elem_name_prefix = 'new_literature'
    end

    unless value.nil?
      pubmed_id = value['pubmed_id']
      open("http://togows.dbcls.jp/entry/pubmed/#{pubmed_id}/title") {|f|
        title = f.read
      }

      open("http://togows.dbcls.jp/entry/pubmed/#{pubmed_id}/au") {|f|
        author = f.read
      }
    end

    render :update do |page|
      page.replace_html "#{elem_name_prefix}[#{id}][title]", title
      page.replace_html "#{elem_name_prefix}[#{id}][author]", author
    end
  end

  def update_metadata
    @metadata = Togodb::Metadata.find_or_create_by_table_id(params[:id])

    if params[:release][:year].empty? || params[:release][:month].empty?
      params[:metadata][:release_date] = nil
    else
      params[:metadata][:release_date] = format("%4d-%02d-01", params[:release][:year], params[:release][:month])
    end

    if params[:update][:year].empty? || params[:update][:month].empty?
      params[:metadata][:update_date] = nil
    else
      params[:metadata][:update_date] = format("%4d-%02d-01", params[:update][:year], params[:update][:month])
    end

    @metadata.attributes = params[:metadata]
    @metadata.save

    if @metadata.licence.nil?
      @metadata.create_licence
    end
    licence = @metadata.licence
    licence.attributes = params[:licence]
    licence.save

    if params[:new_organizations].kind_of?(Array)
      params[:new_organizations].each {|name|
        unless name.empty?
          if name[0, 3] == '%25'
            name = name.gsub(/\%25/, '%')
            name = CGI.unescape(name)
          end
          @metadata.organizations.create(:name => name)
        end
      }
    end
    if params[:organizations].kind_of?(Hash)
      params[:organizations].each {|id, name|
        organization = Togodb::Organization.find(id)
        if name.empty?
          organization.destroy
        else
          if organization.name != name
            organization.name = name
            organization.save
          end
        end
      }
    end

    if params[:dbclasses].kind_of?(Hash)
      params[:dbclasses].each {|id, value|
        metadata_dbclass_id = id.to_i
        database_class_id = value.to_i
        metadata_dbclass = Togodb::MetadataDbclass.find(metadata_dbclass_id)
        if database_class_id == 0
          metadata_dbclass.destroy
        elsif database_class_id == 55
          database_class = Togodb::DatabaseClass.find_or_create_by_name(params[:dbclass_names][id])
          metadata_dbclass.database_class_id = database_class.id
          metadata_dbclass.save
        elsif metadata_dbclass.database_class_id != database_class_id
          metadata_dbclass.database_class_id = database_class_id
          metadata_dbclass.save
        end
      }
    end
    if params[:new_dbclasses].kind_of?(Array)
      params[:new_dbclasses].each_index {|i|
        dbclass_id = params[:new_dbclasses][i].to_i

        if dbclass_id == 55
          d = Togodb::DatabaseClass.find_or_create_by_name(params[:new_dbclass_names][i])
        elsif dbclass_id != 0
          begin
            d = Togodb::DatabaseClass.find(dbclass_id)
          rescue ActiveRecord::RecordNotFound
            d = Togodb::DatabaseClass.new
            d.name = params[:new_dbclass_names][i]
            d.save
          end
        end

        if dbclass_id != 0
          metadata_dbclass = Togodb::MetadataDbclass.new
          metadata_dbclass.metadata_id = @metadata.id
          metadata_dbclass.database_class_id = d.id
          metadata_dbclass.save
        end
      }
    end

    if params[:taxonomy].kind_of?(Hash)
      params[:taxonomy].each {|id, taxonomy|
        metadata_taxonomy = Togodb::Taxonomy.find(id.to_i)
        if taxonomy['taxonomy_name'].empty? && taxonomy['taxonomy_id'].empty?
          metadata_taxonomy.destroy
        else
          metadata_taxonomy.taxonomy_id = taxonomy['taxonomy_id']
          metadata_taxonomy.taxonomy_name = taxonomy['taxonomy_name']
          metadata_taxonomy.save
        end
      }
    end
    if params[:new_taxonomy].kind_of?(Hash)
      params[:new_taxonomy].each {|id, taxonomy|
        if !(taxonomy['taxonomy_id'].empty? && taxonomy['taxonomy_name'].empty?)
          metadata_taxonomy = Togodb::Taxonomy.new
          metadata_taxonomy.metadata_id = @metadata.id
          metadata_taxonomy.taxonomy_id = taxonomy['taxonomy_id']
          metadata_taxonomy.taxonomy_name = taxonomy['taxonomy_name']
          metadata_taxonomy.save
        end
      }
    end

    if params[:literature].kind_of?(Hash)
      params[:literature].each {|id, literature|
        l = Togodb::Literature.find(id.to_i)
        if literature['title'].empty? && literature['author'].empty? && literature['journal'].empty? && literature['pubmed_id'].empty?
          l.destroy
        else
          l.title = literature['title']
          l.author = literature['author']
          l.journal = literature['journal']
          l.pubmed_id = literature['pubmed_id']
          l.save
        end
      }
    end
    if params[:new_literature].kind_of?(Hash)
      params[:new_literature].each {|id, literature|
        if !(literature['title'].empty? && literature['author'].empty? && literature['journal'].empty? && literature['pubmed_id'].empty?)
          @metadata.literatures.create(:title => literature['title'],
                                       :author => literature['author'],
                                       :journal => literature['journal'],
                                       :pubmed_id => literature['pubmed_id'])
        end
      }
    end

    @record = Togodb::Table.find(params[:id])
    render :partial => 'togodb/tab_metadata'
  end


  private
    def construct
      install_files.each &:construct
      reset_routing
    end

    def destruct
      install_files.each &:destruct
      reset_routing
    end

    def test
      install_files.each &:test
    end

    def install_files
      ensure_role :execute

      files = []
      files << Togodb::Generators::Model.new(@record, :confirm=>true)
      files << Togodb::Generators::Controller.new(@record, :confirm=>true)
      files << Togodb::Generators::Page.new(@record)

      if defined?(ActionWebService::Base)
        options = { :wsdl_namespace => wsdl_namespace }
        files << Togodb::Generators::WebService.new(@record, options)
      else
        files << Togodb::Generators::WebServiceNotReady.new(@record)
      end
      return files
    end

    def set_service_to(value)
      ensure_role :execute

      @record.update_attribute :enabled, value
      render :update do |page|
        page[:workspace].replace :partial=>"show"
        page[element_row_id(:action => :list, :id => @record.id)].replace_html :partial=>"list_item"
      end
    end

    def wsdl_namespace
      "%s%s%s" % [request.protocol, request.host_with_port, request.request_uri.sub(/togodb.*$/, @record.singular_name)]
    end

    def reset_routing
      # for Rails2.0
      routes = ::ActionController::Routing::Routes
      routes.load! if routes.respond_to? :load!
    end

    def select_layout
      if @action_name == "login"
        "togodb/admin"
      else
        "togodb/database"
      end
    end

    def rescue_action(exception)
      Togodb.action_error(exception, params)

      if request.xhr?
        erase_render_results

        logger.error Togodb.pretty_error_message(exception)

        render :update do |page|
          page[:workspace].replace_html :partial=>"togodb/exception", :locals=>{:exception=>exception}
          page[:workspace].show
          page[:workspace].visual_effect :highlight
        end
      else
        super
      end
    end

    def redirect_to(*args)
      if request.xhr?
        render :update do |page|
          page.redirect_to *args
        end
      else
        super
      end
    end

    def column_default_values(column_type)
      b_search = (/^(string|text)$/ === column_type.to_s)
      {:enabled => true,
       :sanitize => true,
       :position => @record.columns.map{|c| c.position.nil? ? 0 : c.position}.sort[-1] + 1,
       :action_list => @record.columns.select(&:action_list).size < 5,
       :action_show => true,
       :action_search => b_search,
       :action_luxury => b_search}
    end

    def validate_column_settings
      error_messages = []

      list_disp_orders = []
      params[:records].each_pair {|id, hash|
        column = Togodb::Column.find(id)
        if !hash[:list_disp_order].nil? && !hash[:list_disp_order].empty?
          unless /\A\d+\z/ =~ hash[:list_disp_order]
            error_messages << "#{column[:name]}: List: Invalid number."
          else
            if list_disp_orders.include?(hash[:list_disp_order])
              error_messages << "#{column[:name]}: List: Same list order is specified."
            else
              list_disp_orders << hash[:list_disp_order]
            end
          end
        end
      }
      if !params[:throughs].nil?
        params[:throughs].each_pair {|id, hash|
          if !hash[:list_disp_order1].nil? && !hash[:list_disp_order1].empty?
            through = Togodb::Through.find(id)
            col_name = through[:table2]
            order_column = 'list_disp_order1'
          elsif !hash[:list_disp_order2].nil? && !hash[:list_disp_order2].empty?
            through = Togodb::Through.find(id)
            col_name = through[:table1]
            order_column = 'list_disp_order2'
          else
            next
          end

          unless /\A\d+\z/ =~ hash[order_column]
            error_messages << "#{col_name}: List: Invalid number."
          else
            if list_disp_orders.include?(hash[order_column])
            error_messages << "#{col_name}: List: Same list order is specified."
            else
              list_disp_orders << hash[order_column]
            end
          end
        }
      end

      show_disp_orders = []
      params[:records].each_pair {|id, hash|
        column = Togodb::Column.find(id)
        if !hash[:show_disp_order].nil? && !hash[:show_disp_order].empty?
          unless /\A\d+\z/ =~ hash[:show_disp_order]
            error_messages << "#{column[:name]}: Show: Invalid number."
          else
            if show_disp_orders.include?(hash[:show_disp_order])
              error_messages << "#{column[:name]}: Show: Same show order is specified."
            else
              show_disp_orders << hash[:show_disp_order]
            end
          end
        end
      }
      if !params[:throughs].nil?
        params[:throughs].each_pair {|id, hash|
          if !hash[:show_disp_order1].nil? && !hash[:show_disp_order1].empty?
            through = Togodb::Through.find(id)
            col_name = through[:table2]
            order_column = 'show_disp_order1'
          elsif !hash[:show_disp_order2].nil? && !hash[:show_disp_order2].empty?
            through = Togodb::Through.find(id)
            col_name = through[:table1]
            order_column = 'show_disp_order2'
          else
            next
          end

          unless /\A\d+\z/ =~ hash[order_column]
            error_messages << "#{col_name}: Show: Invalid number."
          else
            if show_disp_orders.include?(hash[order_column])
              error_messages << "#{col_name}: Show: Same show order is specified."
            else
              show_disp_orders << hash[order_column]
            end
          end
        }
      end

      dl_column_orders = []
      params[:records].each_pair {|id, hash|
        column = Togodb::Column.find(id)
        if !hash[:dl_column_order].nil? && !hash[:dl_column_order].empty?
          unless /\A\d+\z/ =~ hash[:dl_column_order]
            error_messages << "#{column[:name]}: Download: Invalid number."
          else
            if dl_column_orders.include?(hash[:dl_column_order])
              error_messages << "#{column[:name]}: Download: Same order is specified."
            else
              dl_column_orders << hash[:dl_column_order]
            end
          end
        end
      }

      error_messages
    end

    ######################################################################
    ### Security methods

    def ensure_role(name)
      case name
      when :superuser, :import_table
        return current_user.flag?(name)
      end

      unless @record
        do_show
      end

      unless @record.is_a?(Togodb::Table)
        raise Togodb::Forbidden, "Missing target table"
      end

      unless @record.authorized_for?(name)
        raise Togodb::Forbidden, "You don't have right permission for #{name}"
      end
    end

    ######################################################################
    ### override ActiveScaffold methods


  protected
    def joins_for_collection
      if current_user.superuser?
        nil
      else
        "LEFT JOIN togodb_roles ON togodb_roles.table_id = togodb_tables.id"
      end
    end

    def active_scaffold_conditions
      if current_user.superuser?
        nil
      else
        ["togodb_roles.user_id = ?", current_user.id]
      end
    end
end
