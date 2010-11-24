class Togodb::MetadataDbclass < ActiveRecord::Base
  set_table_name "togodb_metadata_dbclasses"

  include Migratable
  include ActsAsBits

  column :metadata_id, :integer
  column :database_class_id, :integer

  belongs_to :metadata, :class_name => 'Togodb::Metadata'
  belongs_to :database_class, :class_name => 'Togodb::DatabaseClass'
end
