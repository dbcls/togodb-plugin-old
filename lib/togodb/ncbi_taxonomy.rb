class Togodb::NcbiTaxonomy < ActiveRecord::Base
  set_table_name "togodb_ncbi_taxonomies"

  include Migratable
  include ActsAsBits

  column :name, :string
end
