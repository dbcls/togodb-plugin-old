class Togodb::Role < ActiveRecord::Base
  set_table_name "togodb_roles"

  include Migratable
  column :roles,   :string

  belongs_to :table
  belongs_to :user

  include ActsAsBits
  acts_as_bits :roles,   %w( admin read write execute ), :prefix=>true

  ######################################################################
  ### Class Methods

  class << self
    def instance(table, user)
      raise TypeError, "Expected User but got #{user.class}" unless user.is_a?(Togodb::User)
      raise TypeError, "Expected Table but got #{table.class}" unless table.is_a?(Togodb::Table)

      find_or_initialize_by_user_id_and_table_id(user.id, table.id)
    end
  end

  def authorized_for?(action)
    role?(:admin) or role?(action)
  end

  def admin!
    self.role_admin = true
    save!
  end
end
