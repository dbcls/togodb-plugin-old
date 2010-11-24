module ActiveScaffold::Config
  class Togodb < Base
    def initialize(core_config)
      @core = core_config
      @table_name = nil
      @per_page   = 15
    end

    attr_accessor :table_name
    attr_accessor :per_page

    ######################################################################
    ### Accessor Methods

    def table
      @table ||= ::Togodb::Table.find_by_name(@table_name)
    end

    def setting
      table.setting
    end
  end
end
