class Togodb::Metadata < ActiveRecord::Base
  set_table_name "togodb_metadatas"

  include Migratable
  include ActsAsBits

  column :dbname, :string
  column :contact, :text
  column :url, :string
  column :overall_url, :string
  column :db_catalog_url, :string
  column :disp_data_class, :boolean
  column :query_search, :boolean
  column :web_service, :boolean
  column :web_service_url, :string
  column :need_user_registration, :boolean
  column :data_download_url, :string
  column :summary, :text
  column :referenced_db, :text
  column :release_date, :date
  column :update_date, :date
  column :background, :text
  column :feature, :text

  belongs_to :table, :class_name => "Togodb::Table", :foreign_key => "table_id"

  has_many :organizations, :class_name => "Togodb::Organization", :foreign_key => "metadata_id"
  has_many :metadata_dbclasses, :class_name => "Togodb::MetadataDbclass", :foreign_key => "metadata_id"
  has_many :database_classes, :class_name => "Togodb::DatabaseClass", :through => :metadata_dbclasses
  has_many :taxonomies, :class_name => "Togodb::Taxonomy", :foreign_key => "metadata_id"
  has_one  :licence, :class_name => "Togodb::Licence", :foreign_key => "metadata_id"
  has_many :literatures, :class_name => "Togodb::Literature", :foreign_key => "metadata_id"
end
