# used for just a migration file

class Togodb::Migrations::OpenIdAuthenticationAssociation < ActiveRecord::Base
  set_table_name "open_id_authentication_associations"

  include Migratable
  column :issued,     :integer 
  column :lifetime,   :integer
  column :handle,     :string
  column :assoc_type, :string
  column :server_url, :binary
  column :secret,     :binary
end
