class Togodb::Licence < ActiveRecord::Base
  set_table_name "togodb_licences"

  include Migratable
  include ActsAsBits

  column :organization, :text
  column :redistributable, :integer
  column :disp_credit, :integer
  column :corruption, :integer
  column :disp_licencing, :integer
  column :commercial_use, :integer
  column :special_affairs, :text

  column :metadata_id, :integer
end
