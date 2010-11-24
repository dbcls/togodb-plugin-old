class Togodb::Setting < ActiveRecord::Base
  set_table_name "togodb_settings"

  include Migratable
  include ActsAsBits

  ######################################################################
  ### Schema

  column :label,          :string
  column :actions,        :string
  column :externals,      :text

  ### Global

  column :html_title,     :string
  column :page_header,    :text
  column :page_footer,    :text

  column :html_head,      :text

  ### Bits

  acts_as_bits :actions, [:list, :create, :show, :update, :delete, :search, :nested, :subform, :service], :prefix=>true

  ### List Action

  column :per_page,       :integer

  ######################################################################
  ### Serialized

  serialize :externals, Array

  ######################################################################
  ### Associations

  belongs_to :table, :class_name=>"Togodb::Table", :foreign_key=>"table_id"

  ######################################################################
  ### Validations

  before_save {|record| record[:per_page] ||= 15; true }

  ######################################################################
  ### Accessor methods

  def active_scaffold_actions
    actions_hash.select{|k,v| v}.map{|a| a[0].sub(/^action_/,'')}.delete_if{|i| "service" == i}
  end


  ######################################################################
  ### External class
  ######################################################################

  require 'open3'

  class External
    delegate :exist?, :to=>"pathname"

    class NotFound       < RuntimeError; end
    class NotImplemented < RuntimeError; end

    attr_reader :name

    def initialize(name)
      @name = name.to_s
    end

    def search(query)
      report "search [%s]" % query
      popen3_for(:search) do |stdin, stdout, stderr|
        stdin.print query
        stdin.close
        stdout.read.split
      end
    end

    def label
      name.humanize
    end

    private
      def pathname
        Pathname(RAILS_ROOT) + "bin" + "external_search" + @name
      end

      def command_for(name)
        pathname + "bin" + name.to_s
      end

      def popen3_for(command_name, &block)
        command = command_for(command_name)
        if command.exist?
          Open3.popen3(command, &block)
        else
          raise NotImplemented, command_name.to_s
        end
      end

      def report(message)
        string = "%s(%s) %s" % [self.class.name.demodulize, name, message]
        ::Togodb.syslog(string)
      end
  end

  def valid_externals
    (externals || []).map{|name| external_for(name) rescue nil}.compact
  end

  def external_for(name)
    ext = External.new(name)
    raise External::NotFound, name unless ext.exist?
    return ext
  end
end
