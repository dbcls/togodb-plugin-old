class TogodbUserController < TogodbController
  layout "togodb/user"
  helper "togodb/external_search"
  helper "luxury_search"
  before_filter :role_required

  active_scaffold "Togodb::User" do |config|
    names = ["login", "password"] + Togodb::User.flag_names

    config.actions = %w( nested search create update delete list subform show )
    config.columns = names

    config.columns[:superuser].label = "Super User"
    config.columns[:password].description = "Used for local account"

    config.list.columns = ["login", "role"]
    config.list.sorting = {:login => :asc }
    config.list.label = as_("User Browser")
    config.list.per_page = 20

    config.update.columns.add names
    config.create.columns.add names

    ######################################################################
    ### Record links

    config.search.columns = %w( login )
  end

  active_scaffold_config.action_links.delete :show
  active_scaffold_config.action_links[:show_search].type = false

  private
    def role_required
      current_user.superuser?
    end

  protected
    # due to stupid inheritance
    def active_scaffold_conditions
      @active_scaffold_conditions ||= []
    end

    def active_scaffold_joins
      @active_scaffold_joins ||= []
    end
end
