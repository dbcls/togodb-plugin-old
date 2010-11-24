
class Togodb::Through < ActiveRecord::Base
  set_table_name "togodb_throughs"

  include Migratable

  column :name,          :string
  column :table1,        :string
  column :table2,        :string
  column :column1,       :string
  column :column2,       :string
  column :created_at,    :datetime

  cattr_accessor :reserved_table_names
  self.reserved_table_names = %w( schema_info togodb_tables togodb_throughs togodb_columns togodb_settings togodb_syslogs togodb_users togodb_roles open_id_authentication_associations open_id_authentication_nonces )

=begin
  def initialize()
    super
    # create_table  through
    #ActiveRecord::Base.connection.create_table "hoge" do |t|
    #  t.column "aaa", :string
    #end
  end
=end
  
  def create_table()
    begin
      ActiveRecord::Base.connection.drop_table name
    rescue
    end
    ActiveRecord::Base.connection.create_table name do |t|
#      t.column table1+"_id" ,:string
#      t.column table2+"_id" ,:string
      t.column table1+"_id", :integer
      t.column table2+"_id", :integer
    end
    begin
    ActiveRecord::Base.connection.add_index name, table1+"_id"
    rescue
    end
    begin
    ActiveRecord::Base.connection.add_index name, table2+"_id"
    rescue
    end
    begin
    ActiveRecord::Base.connection.add_index table1, column1
    rescue
    end
    begin
    ActiveRecord::Base.connection.add_index table2, column2
    rescue
    end

    
  end

  def table_name
    name
  end
  
  def class_name
    name.classify
  end





=begin
  cattr_accessor :reserved_table_names
  self.reserved_table_names = %w( schema_info togodb_tables togodb_joins togodb_joincolumns togodb_columns togodb_settings togodb_syslogs togodb_users togodb_roles open_id_authentication_associations open_id_authentication_nonces )

  class << self
    def available_tables
      connection.tables - reserved_table_names
    end

    def sync
      available_tables.each do |table|
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


=end
end


