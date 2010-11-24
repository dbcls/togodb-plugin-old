module Togodb::WebService
  def self.append_features(base)
    base.class_eval do
      dsl_accessor :model,  :default=>proc{|klass| klass.name.sub(/Service$/, '').constantize}
      dsl_accessor :struct, :default=>proc{|klass| ("%sStructs::%s" % [model, model]).constantize}
      dsl_accessor :controller, :default=>proc{|klass| klass.name.sub(/Service$/, 'Controller').constantize}

      include InstanceMethods
    end
    super
  end

  module InstanceMethods
    def count(query)
      self.class.model.count(:conditions=>conditions_for(query))
    end

    def search(query, limit, offset)
      conds   = conditions_for(query)
      records = self.class.model.find(:all, :conditions=>conds, :limit=>limit, :offset=>offset)
      structs = records.map{|record| record2struct(record)}
      return structs
    end

    private
      def active_scaffold_config
        self.class.controller.active_scaffold_config
      end

      def conditions_for(query)
        return nil if (query = query.to_s.strip).blank?

        columns = active_scaffold_config.search.columns
        conds   = columns.map{|column|::LuxurySearch::Field.new(column, query).condition}
        conds.join(' OR ')
      end

      def record2struct(record)
        returning struct = self.class.struct.new do
          struct.each_pair{|key, val| struct.send("#{key}=", record.send(key))}
        end
      end
    end
end

