class Togodb::Table < ActiveRecord::Base
  set_table_name "togodb_tables"

  include Migratable

  column :name,          :string
  column :enabled,       :boolean
  column :imported,      :boolean
  column :sortable,      :boolean, :default => true
  column :updated_at,    :datetime

  has_many :columns, :class_name=>"Togodb::Column",  :foreign_key=>"table_id", :dependent=>:destroy, :order=>"position"
  has_one  :setting, :class_name=>"Togodb::Setting", :foreign_key=>"table_id", :dependent=>:destroy
  has_many :roles,   :class_name=>"Togodb::Role",    :foreign_key=>"table_id", :dependent=>:destroy
  has_one  :metadata, :class_name => "Togodb::Metadata", :foreign_key => "table_id", :dependent=>:destroy

  alias_method :has_one_setting, :setting

  cattr_accessor :reserved_table_names
  self.reserved_table_names = %w( schema_info togodb_tables togodb_throughs togodb_columns togodb_settings togodb_syslogs togodb_users togodb_roles open_id_authentication_associations open_id_authentication_nonces togodb_database_classes togodb_licences togodb_literatures togodb_metadata_dbclasses togodb_metadata_taxonomies togodb_metadatas togodb_organizations togodb_taxonomies togodb_ncbi_taxonomies)

  class << self
    def available_tables
      connection.tables - reserved_table_names
    end

    def sync
      available_tables.each do |table|
# koko?
      next if table =~ /^through_table/ 
        sync_table_for(table)
      end
    end

    private
      def sync_table_for(name)
        table = find_by_name(name) || create!(:name=>name, :enabled=>false, :imported=>false)
        table.sync
      end
  end

  def sync
    sync_columns
  end

  ######################################################################
  ### Authorizations for ActiveScaffold

  def authorized_for?(options)
    return true if new_record?
    return true if current_user and current_user.superuser?

    options = {:action=>options} if options.is_a?(Symbol)

    logger.debug "#{self.class.name}#authorized_for?(#{options[:action]})"
    logger.debug "  table: #{self.inspect}"
    logger.debug "  current_user: #{current_user.inspect}"
    logger.debug "  current_role: #{current_role.inspect}"

    case options[:action]
    when :start then current_role.authorized_for?(:execute) and !enabled
    when :stop  then current_role.authorized_for?(:execute) and  enabled
    when :admin, :read, :write, :execute
      current_role.authorized_for?(options[:action])
    else super
    end
  end

  def role_for(user = current_user)
    if user
      Togodb::Role.find(:first, :conditions=>["user_id = ? AND table_id = ?", user.id, id])
    else
      nil
    end
  end

  def current_role
    role_for(current_user) || Togodb::Role.new
  end

  ######################################################################
  ### Associations

  def setting
    has_one_setting || default_setting
  end

  def default_setting
    label = name.to_s.humanize
    attributes = {
      :label          => label,
      :html_title     => label,
      :page_header    => "<h2>#{label}</h2>",
      :page_footer    => "",
      :per_page       => 15,
      :action_list    => true,
      :action_show    => true,
      :action_show    => true,
      :action_search  => true,
      :action_nested  => true,
      :action_subform => true,
      :action_service => true,
    }
    build_setting attributes
  end

  ######################################################################
  ### Activator Methods

  def construct(activator = Togodb::Generators::Model)
    activator.new(self).construct
  end

  def destruct(activator = Togodb::Generators::Model)
    activator.new(self).destruct
  end

  def active_record
    class_name.constantize
  rescue NameError
    construct
    class_name.constantize
  end

  ######################################################################
  ### Accessor Methods

  def table_name
    name.to_s
  end

  def class_name
    table_name.to_s.singularize.classify
  end

  def singular_name
    table_name.to_s.singularize
  end

  def primary_key
    array = columns.select{|c| c.primary_key}.map(&:name)
    case array.size
    when 0 then "id"
    when 1 then array.first
    else        array
    end
  end

  def primary_column_name
    columns.each do |column|
      return column.name if column.record_name
    end
    return nil
  end

  ######################################################################
  ### Testing Methods

  def exist?
    ActiveRecord::Base.connection.tables.include?(table_name)
  end

  ######################################################################
  ### Migrations

  def migrate(direction = :up)
    klass = active_record
    if (direction == :up) ^ exist?
      klass.send :include, Migratable
      klass.migrator.columns.clear
      columns.each do |column|
        next unless column.enabled?
        klass.column column[:name], column[:type]
      end
      klass.migrate(direction)
    end
    return klass
  end

  def enabled_columns
    columns.select(&:enabled)
  end

  ######################################################################

  def list_columns
    Togodb::Column.find(:all, :conditions => "table_id = #{id} AND list_disp_order > 0", :order => 'list_disp_order')
  end

  def show_columns
    Togodb::Column.find(:all, :conditions => "table_id = #{id} AND show_disp_order > 0", :order => 'show_disp_order')
  end

  def through_tables
    Togodb::Through.find(:all, :conditions => ["table1 = ? OR table2 = ?", name, name])
  end

  def joined_tables
    tables = []
    through_tables.each {|t|
      if t.table1 == name
        tables << {:name => t.table2, :list_disp_order => t.list_disp_order1}
      elsif t.table2 == name
        tables << {:name => t.table1, :list_disp_order => t.list_disp_order2}
      end
    }

    tables
  end

  def list_column_names
    c_names = list_columns.map{|c| {:list_disp_order => c.list_disp_order, :name => c.name}}
    j_tables = joined_tables.select{|t| (!t[:list_disp_order].nil?) && t[:list_disp_order] > 0}
    j_tables.each {|t|
      c_names << {:list_disp_order => t[:list_disp_order], :name => t[:name]}
    }

    c_names.sort{|a, b| a[:list_disp_order] <=> b[:list_disp_order]}
  end

  def show_column_names
    c_names = show_columns.map{|c| {:show_disp_order => c.show_disp_order, :name => c.name}}
    j_tables = joined_tables.select{|t| (!t[:show_disp_order].nil?) && t[:show_disp_order] > 0}
    j_tables.each {|t|
      c_names << {:show_disp_order => t[:show_disp_order], :name => t[:name]}
    }

    c_names.sort{|a, b| a[:show_disp_order] <=> b[:show_disp_order]}
  end

  def webservice_column?
    columns.each {|column|
      return true if column.web_service?
    }
    return false
  end

  private
    def sync_columns
      records_hash    = columns.group_by(&:name)
      created_columns = connection.columns(name).select{|column| !records_hash.delete(column.name)}

      records_hash.values.flatten.each{|dropped| dropped.destroy}
      created_columns.each{|column| register_column(column)}
    end

    # NOTE: a new column could be created via togodb_import_controller
    def register_column(column)
      max_position = columns.map(&:position).max || 0
      primary_key  = !columns.map(&:primary_key).any?

      attributes = {
        :name          => column.name,
        :type          => column.type.to_s,
        :label         => column.name.humanize,
        :primary_key   => primary_key,
        :sanitize      => true,
        :action_list   => (/name/ === column.name) || (max_position < 5),
        :action_show   => true,
        :action_search => column.text?,
        :action_luxury => column.text?,
        :position      => max_position + 1,
      }
      record = columns.build(attributes)
      record.save!
    end
end
