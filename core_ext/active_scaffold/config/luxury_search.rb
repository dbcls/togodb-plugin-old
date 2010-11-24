module ActiveScaffold::Config
  class LuxurySearch < Base
    self.crud_type = :read

    def initialize(core_config)
      @core = core_config

      @full_text_search = self.class.full_text_search?

      # start with the ActionLink defined globally
      @link = self.class.link.clone
      
      @operators = self.class.operators.clone
    end


    # global level configuration
    # --------------------------
    # the ActionLink for this action
    cattr_reader :link
    @@link = ActiveScaffold::DataStructures::ActionLink.new('show_search', :label => 'Search', :type => :table, :security_method => :search_authorized?)

    cattr_writer :full_text_search
    def self.full_text_search?
      @@full_text_search
    end
    @@full_text_search = true
    
    #
    # Database statements operators.
    # This hash is used to get the correct database operator when constructing the WHERE statement
    # You may modify it locally or globally to suit your database dialect (should be fairly normalized though)
    cattr_accessor :operators
    @@operators = {
      :and => 'AND', :or => 'OR', :in => 'IN', :between => 'BETWEEN', :like => 'LIKE', :is => 'IS', :is_not => 'IS NOT',
      :equal => '=', :different => '<>', :less_than => '<', :less_than_or_equal => '<=', :greater_than => '>', :greater_than_or_equal => '>=',
      :'=' => '=', :'<>' => '<>', :< => '<', :<= => '<=', :> => '>', :>= => '>='
    }
    
    # instance-level configuration
    # ----------------------------

    # provides access to the list of columns specifically meant for the Search to use
    def columns
      # we want to delay initializing to the @core.columns set for as long as possible. Too soon and .search_sql will not be available to .searchable?
      # Defaults to any searchable column
      unless @columns
        self.columns = @core.columns.collect{|c| c.name if c.searchable?}.compact
      end
      @columns
    end

    def columns=(val)
      @columns = ActiveScaffold::DataStructures::ActionColumns.new(*val)
      @columns.action = self
    end

    attr_writer :full_text_search
    def full_text_search?
      @full_text_search
    end

    # the ActionLink for this action
    attr_accessor :link
    
    # Database operators hash (see above)
    attr_accessor :operators
  end
end
