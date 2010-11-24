# used for just a migration file

class Togodb::Migrations::OpenIdAuthenticationNonce < ActiveRecord::Base
  set_table_name "open_id_authentication_nonces"

  include Migratable
  column :timestamp, :integer, :null => false
  column :server_url, :string, :null => true
  column :salt, :string, :null => false
end
