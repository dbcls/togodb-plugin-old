class Togodb::Taxonomy < ActiveRecord::Base
  set_table_name "togodb_taxonomies"

  include Migratable
  include ActsAsBits

  column :metadata_id, :integer
  column :taxonomy_id, :integer
  column :taxonomy_name, :string

  belongs_to :metadata, :class_name => 'Togodb::Metadata', :foreign_key => 'metadata_id'
end
