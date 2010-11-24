class Togodb::Literature < ActiveRecord::Base
  set_table_name "togodb_literatures"

  include Migratable
  include ActsAsBits

  column :title,       :text
  column :author,      :text
  column :journal,     :string
  column :pubmed_id,   :integer

  column :metadata_id, :integer
end
