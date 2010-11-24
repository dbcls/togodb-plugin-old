module LuxurySearch
  ######################################################################
  ### Data

  Token = Struct.new(:value1, :value2, :negative)
  class Token
    dsl_accessor :op, :default=>"="

    def initialize(*args)
      super
      self.negative ||= false
    end

    def not
      dup.not!
    end

    def not!
      self.negative = !self.negative
      return self
    end

    def valid?
      !blank?
    end

    def blank?
      value1.blank?
    end

    def statement_for(column_name)
      "%s %s ?" % [column_name, self.class.op.to_s.upcase]
    end

    def parameters
      [value1]
    end

    def condition_for(column_name)
      statement = statement_for(column_name)
      statement = "NOT (%s)" % [statement] if negative
      [statement, *parameters]
    end
  end

  class Equal < Token
    op "="

    def parameters
      dbname = ActiveRecord::Base.establish_connection.config[:adapter]
      case (dbname)
        when "postgresql" then value1.to_i == 1 ? ['true'] : ['false']
        else [value1]
      end
    end
  end

  class Gt < Token
    op ">"
  end

  class Gtoe < Token
    op ">="
  end

  class Lt < Token
    op "<"
  end

  class Ltoe < Token
    op "<="
  end

  class Between < Token
    op :between

    def blank?
      value1.blank? or value2.blank?
    end

    def statement_for(column_name)
      "%s BETWEEN ? AND ?" % [column_name]
    end

    def parameters
      [value1, value2]
    end
  end

  class Regexp < Token
    dbname = ActiveRecord::Base.establish_connection.config[:adapter]
    case (dbname)
      when "mysql"  then op "rLIKE" 
      when "sqlite3"  then op "REGEXP" 
      when "postgresql" then op "~"
      else               op :like
    end

    def parameters
      if value1 =~ /^\/(.+)\//
        ["#{ $1 }"]
      else
        ["#{ value1 }"]
      end
    end

  end

  class Like < Token
    op :like
  
    def parameters
      ["%#{ value1 }%"]
    end
  end

  ######################################################################
  ### Parser

  class QueryTokenizer
    def initialize(value)
      @value  = normalize_value(value)
      @tokens = []
    end

    def normalize_value(value)
      value = value.to_s.strip
      value = value.gsub(/\s*(<=?|>=?|\.\.)\s*/){$1}
      value = value.gsub(/(-)/){" #{$1} "}
    end

    def add(klass, value1, value2 = nil)
      @tokens << klass.new(value1, value2, !!@negative)
      @negative = false
    end

    def negative_sentence
      @negative = !@negative
    end

    def execute
      @value.split.each do |element|
        case (e = element.strip)
        when "-"	then negative_sentence # not
        when /\.\./	then add(Between, $`, $')
        when /^<=/	then add(Ltoe   , $')
        when /^</	then add(Lt     , $')
        when /^>=/	then add(Gtoe   , $')
        when /^>/	then add(Gt     , $')
        when /^\/.+\//  then add(Regexp , e)
        when /^=/       then add(Equal  , $')
        else		     add(Like   , e)
        end
      end
      return @tokens
    end
  end

  ######################################################################
  ### Column field

  class Field
    def initialize(column, value)
      @column = column
      @value  = value
      @tokens = QueryTokenizer.new(value).execute
    end

    def search_sql
      if @column.is_a?(ActiveScaffold::DataStructures::Column)
        @column.search_sql
      else
        @column.to_s
      end
    end

    def conditions
      @tokens.select(&:valid?).map{|token| token.condition_for(search_sql) }
    end

    def condition
      conditions.reject(&:blank?).map{|c| ActiveRecord::Base.send(:sanitize_sql, c)}.join(' AND ')
    end
  end

end
