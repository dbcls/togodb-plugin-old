class Togodb::Organization < ActiveRecord::Base
  include Migratable
  include ActsAsBits

  set_table_name "togodb_organizations"

  column :name, :string
  column :metadata_id, :integer
end
