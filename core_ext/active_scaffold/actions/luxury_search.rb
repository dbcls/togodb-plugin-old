module ActiveScaffold::Actions
  module LuxurySearch
    def self.included(base)
      base.skip_before_filter :do_search if skip_filter?(base, :do_search)
      base.before_filter :luxury_search_authorized?, :only => :show_search
      base.before_filter :do_search
    end

    def self.skip_filter?(base, filter)
      if base.respond_to?(:find_filter)
        base.find_filter(filter)
      else
        # seems Rails2.1+
        true
      end
    end

    def show_search
      params[:search] ||= {}
      respond_to do |type|
        type.html do
          if successful?
            render(:partial => "luxury_search", :layout => true)
          else
            return_to_main
          end
        end
        type.js { render(:partial => "luxury_search", :layout => false) }
      end
    end

    protected

    def do_search
#      Togodb.logger.debug "do_search: %s" % caller[0..3].inspect
      case (parameters = params[:search])
      when NilClass
        # nop
      when String
        do_simple_search(parameters)
      when Hash
        do_luxury_search(parameters)
      else
        raise UnknownParameter, parameters.class.to_s
      end
    end

    def do_simple_search(query)
      return if (query = query.to_s.strip).blank?
      valid_columns = active_scaffold_config.search.columns

      condition_builder = ::LuxurySearch::ConditionBuilder.new
      condition = condition_builder.build(query, valid_columns)
      
      self.active_scaffold_conditions = merge_conditions(active_scaffold_conditions, *condition)
      self.active_scaffold_joins.concat valid_columns.map(&:includes).flatten.uniq.compact
      active_scaffold_config.list.user.page = nil
    end

    def do_luxury_search(parameters)
      valid_columns = active_scaffold_config.luxury_search.columns

      columns = []
      parameters.each do |column_name, value|
        next if value.nil? || value.to_s.strip.blank?
        next unless valid_columns.include?(column_name)
        next unless column = active_scaffold_config.columns[column_name]
        columns << column
      end
        
      condition_builder = ::LuxurySearch::ConditionBuilder.new(false)
      condition = condition_builder.build(parameters, columns)

      self.active_scaffold_conditions = merge_conditions(active_scaffold_conditions, *condition)
      self.active_scaffold_joins.concat valid_columns.map(&:includes).flatten.uniq.compact
      active_scaffold_config.list.user.page = nil
    end

    # The default security delegates to ActiveRecordPermissions.
    # You may override the method to customize.
    def luxury_search_authorized?
      authorized_for?(:action => :read)
    end

    class UnknownOperator  < RuntimeError; end
    class UnknownParameter < RuntimeError; end

  end
end
