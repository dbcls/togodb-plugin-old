class Togodb::DatabaseClass < ActiveRecord::Base
  set_table_name "togodb_database_classes"

  include Migratable
  include ActsAsBits

  column :name, :string

  has_many :metadata_dbclasses, :class_name => 'Togodb::MetadataDbclass', :foreign_key => 'database_class_id'
  has_many :metadatas, :class_name => 'Togodb::Metadata', :through => :metadata_dbclasses
end
