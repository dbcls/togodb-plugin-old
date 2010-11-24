class Togodb::User < ActiveRecord::Base
  set_table_name "togodb_users"

  ######################################################################
  ### Migration

  include Migratable
  column :login,         :string, :index=>true
  column :password,      :string
  column :flags,         :string
  column :tables,        :string

  include ActsAsBits
  acts_as_bits :flags,  %w( superuser import_table )

  has_many :roles,   :class_name=>"Togodb::Role",    :foreign_key=>"user_id", :dependent=>:destroy

  ######################################################################
  ### Validations

  validates_presence_of :login
  validates_uniqueness_of :login

  ######################################################################
  ### Instance Methods

  def default_roles
    self.import_table = true
  end

  ######################################################################
  ### Testing

  def local_account?
    !password.blank?
  end

  ######################################################################
  ### Printing

  def rwx_for(column)
    [
     send("#{column}_read?")    ? "r" : "-",
     send("#{column}_write?")   ? "w" : "-",
     send("#{column}_execute?") ? "x" : "-",
    ].join
  end

  def to_label
    login
  end

  ######################################################################
  ### Class Methods

  class << self
    def new(*args)
      returning(super){|obj| obj.default_roles}
    end

    def register(login, password = nil)
      user = find_by_login(login)
      unless user
        user = new
        user.login    = login
        user.password = password.to_s
        user.save!
      end
      return user
    end

    # authorize as local account
    def authorize(login, password)
#3      user = Togodb::User.find_by_login(login.to_s) or return nil
      user = Togodb::User.find(:first, :conditions => ['login = ?', login.to_s]) or return nil #3
      return nil unless user
      return nil unless user.local_account?
      return nil unless user.password.to_s == password.to_s
      return user
    end

    def reset_root_account
#3      root = find_or_create_by_login('root')
      if root = Togodb::User.find(:first, :conditions => ['login = ?', 'root']) #3
      else
        root = Toogodb::User.new
      end
      root.login     = 'root'   # Set login explicitly becuase sometimes the value is nil. AR bug?
      root.password  = 'root'
      root.superuser = true
      root.save!
    end
  end

end
