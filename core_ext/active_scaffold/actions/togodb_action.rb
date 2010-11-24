module ActiveScaffold::Actions
  module TogodbAction
    def self.included(base)
      base.delegate :togodb, :to=>"active_scaffold_config"
    end

    def external_search
      ext = togodb.setting.external_for(params[:id])
      ids = ext.search(params[:search])[0,togodb.per_page]
      self.active_scaffold_conditions = ["id IN (?)", ids]
      update_table
    end
  end
end
