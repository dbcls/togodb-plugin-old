$KCODE = "UTF8"

module LuxurySearch
  class ConditionBuilder
    def initialize(simple_search = true)
      @simple_search = simple_search
      init_field

      if ActiveRecord::Base.connection.adapter_name.downcase == "postgresql"
        @like_op = "ILIKE"
      else
        @like_op = "LIKE"
      end
    end
    
    def init_field
      @tokens = []
      @terms = []
      @operators = []
    end
    
    def build(search_values, columns)
      if @simple_search
        build_for_simple_search(search_values, columns)
      else
        build_for_luxury_search(search_values, columns)
      end
    end
    
    def build_for_simple_search(search_string, columns)
      parse(search_string)
      conditions_for_string(search_string, columns).map {|s| "(#{s})"}.join(" OR ")
    end
    
    def build_for_luxury_search(search_values, columns)
      conditions = []
      columns.each {|column|
        query = search_values[column.name]
        case column.column.type
        when :date then
          condition = condition_for_date(query, column)
        when :time then
          condition = condition_for_time(query, column)
        when :integer, :float, :decimal then
          condition = condition_for_numeric(query, column)
        when :boolean then
          condition = condition_for_boolean(query, column)
        else
          parse(query)
          condition = condition_for_string(query, column)
          init_field
        end
        conditions << condition unless condition.blank?
      }
      
      conditions.map{|s| "(#{s})"}.join(" AND ")
    end

    def conditions_for_string(search_string, columns)
      conditions = []
      columns.each {|column|
        condition = condition_for_string(search_string, column)
        conditions << condition unless condition.blank?
      }
      
      conditions
    end
    
    def condition_for_string(search_string, column)
      condition = @terms[0].to_sql(column.search_sql, @like_op, @simple_search)
      @terms[1 .. -1].zip(@operators).each {|term, operator|
        condition << " #{operator} #{term.to_sql(column.search_sql, @like_op, @simple_search)}"
      }
      
      condition
    end
    
    def condition_for_numeric(query, column)
      conditions = []
      unless query[:from].blank?
        conditions << column.search_sql + ">=" + query[:from]
      end
      unless query[:to].blank?
        conditions << column.search_sql + "<=" + query[:to]
      end
      
      conditions.join(' AND ')
    end
    
    def condition_for_date(query, column)
      from = query[:from]
      to = query[:to]
      conditions = []
      unless empty_query?(from)
        from[:year] ||= 1970
        from[:month] ||= 1
        from[:day] ||= 1
        conditions << column.search_sql + ">=" + sprintf("'%4d-%02d-%02d'", from[:year], from[:month], from[:day])
      end
      
      unless empty_query?(to)
        to[:year] ||= from[:year]
        to[:month] ||= 12
        to[:day] ||= 31
        conditions << column.search_sql + "<=" + sprintf("'%4d-%02d-%02d'", to[:year], to[:month], to[:day])
      end
      
      conditions.join(' AND ')
    end
    
    def condition_for_time(query, column)
      from = query[:from]
      to = query[:to]
      conditions = []
      unless empty_query?(from)
        from[:hour] ||= 0
        from[:min] ||= 0
        from[:sec] ||= 0
        conditions << column.search_sql + ">=" + sprintf("'%02d:%02d:%02d'", from[:hour], from[:min], from[:sec])
      end
      
      unless empty_query?(to)
        to[:hour] ||= 23
        to[:min] ||= 23
        to[:sec] ||= 59
        conditions << column.search_sql + "<=" + sprintf("'%02d:%02d:%02d'", to[:hour], to[:min], to[:sec])
      end
      
      conditions.join(' AND ')
    end
    
    def condition_for_boolean(query, column)
      return "" if query.blank?
      
      dbname = ActiveRecord::Base.establish_connection.config[:adapter]
      case (dbname)
        when "postgresql" then
        value = query.to_i == 1 ? 'true' : 'false'
      else
        value = query
      end
      
      column.search_sql + "=" + value
    end
    
    def parse(search_string)
      to_token(search_string)
      prev_term_is_operator = true
      @tokens.each {|tk|
        if prev_term_is_operator
          @terms << tk
          prev_term_is_operator = false
        else
          if tk.double_quoted || !(tk.value.upcase == 'AND' || tk.value.upcase == 'OR')
            @operators << 'AND'
            @terms << tk
            prev_term_is_operator = false
          else
            @operators << tk.value.upcase
            prev_term_is_operator = true
          end
        end
      }
    end
    
    def to_token(search_string)
      negative = false
      search_string.split(/\"/).map {|s| s.strip}.each_with_index {|w, i|
        next if w.empty?
        if w == '-'
          negative = true
          next
        end
        if i % 2 == 0
          w.split(/[\s　]+/).each {|t|
            if t == '-'
              negative = true
            else
              @tokens << Token.new(t, false, false)
              negative = false              
            end
          }
        else
          # double quoted token
          @tokens << Token.new(w, true, negative)
          negative = false
        end
      }
    end
    
    def empty_query?(query)
      if query.kind_of?(Hash)
        query.values.each {|v|
          return false unless v.blank?
        }
        return true
      elsif query.kind_of?(String)
        return query.strip.blank?
      else
        return true
      end
    end
    
    class Token
      def initialize(value, double_quoted, negative)
        if !double_quoted && !negative
          @negative = /\A\-/ =~ value
        else
          @negative = negative
        end
        
        if double_quoted
          @value = value
        else
          @value = @negative ? value[1 .. -1] : value
        end
        
        @double_quoted = double_quoted
      end

      def to_sql(column_name, operation, simple_search = true)
        ActiveRecord::Base.send(:sanitize_sql, condition_for(column_name, operation))
      end
      
      def condition_for(column_name, operation)
        statement = statement_for(column_name, operation)
        statement = "NOT (%s)" % [statement] if @negative
        case operation.upcase
        when "LIKE", "ILIKE" then
          value = "%#{@value}%"
        else
          value = @value
        end
        
        [statement, value]
      end

      def statement_for(column_name, operation)
        "%s %s ?" % [column_name, operation]
      end
      
      attr_accessor :value, :double_quoted, :negative
    end
    
  end
end
