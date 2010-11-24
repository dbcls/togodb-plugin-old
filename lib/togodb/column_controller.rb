class Togodb::ColumnController < ApplicationController
  layout "togodb"

  active_scaffold :togodb_column do |config|
#    config.actions << :sortable
    config.actions.exclude :search, :delete, :create
    config.columns = %w( name label type action_list action_show action_search action_luxury table )
    config.list.per_page = 1000

    config.columns[:action_list].list_ui = :checkbox
    config.columns[:action_list].inplace_edit = true

    config.columns[:action_show].list_ui = :checkbox
    config.columns[:action_show].inplace_edit = true

    config.columns[:action_search].list_ui = :checkbox
    config.columns[:action_search].inplace_edit = true

    config.columns[:action_luxury].list_ui = :checkbox
    config.columns[:action_luxury].inplace_edit = true

    config.columns[:label].inplace_edit = true
  end

  active_scaffold_config.action_links.delete(:show)
  active_scaffold_config.action_links.delete(:update)

  def update_column
    super
    @record.table.save!         # update timestamp
  end

#   def table
#     do_list
#     @page.items.reject!{|r| r.name == "id"}
#     render :partial=>"list"
#   end
end
