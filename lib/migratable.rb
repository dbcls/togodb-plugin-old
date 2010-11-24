module Migratable
  def self.append_features(base)
    base.class_eval do
      extend ClassMethods

      dsl_accessor :table_options, :default=>{}
      dsl_accessor :migrator, :default=>proc{|ar| Migratable::Migrator.new(ar)}

      class << self
        delegate :column, :migrate, :to=>"migrator"
      end
    end
    super
  end

  def self.migrate(direction = :up)
    classes = []
    ObjectSpace.each_object(Class) do |k|
      classes << k if k < self
    end
    classes.inject({}) do |hash, k|
      hash[k.to_s] = k.migrate(direction)
      hash
    end
  end

  module ClassMethods
    def belongs_to(association_id, options = {})
      name = options[:foreign_key] || "#{ association_id }_id"
      column name, :integer
      super
    end
  end

  class Migrator
    delegate :connection, :table_name, :reset_column_information, :to=>"@active_record"
    delegate :tables, :create_table, :drop_table, :add_column, :to=>"connection"
    attr_reader :columns

    def initialize(active_record, options = nil)
      @active_record = active_record
      @table_options = options || @active_record.table_options || {}
      @columns = ActiveSupport::OrderedHash.new
    end

    def column(*args)
      @columns[args.first] = args
    end

    def exist?
      tables.include? table_name
    end

    def up(&block)
      create_table table_name, @table_options do |t|
        @columns.values.each do |args|
          t.__send__ :column, *args
        end
      end
    end

    def down(&block)
      drop_table table_name
    end

    def strict(&block)
      return up(&block) if !exist?

      @columns.each do |name, args|
        next if @active_record.columns_hash[name.to_s]
        add_column(table_name, *args)
      end
    end

    def migrate(action = :up, &block)
      case action.to_s
      when "up"
        return nil if exist?
        up(&block)
      when "down"
        return nil if !exist?
        down(&block)
      when "strict"
        strict(&block)
      else
        raise ArgmentError, "Valid directions are on of :up/:down/:strict for migrate"
      end

      reset_column_information
      return table_name
    end
  end
end
