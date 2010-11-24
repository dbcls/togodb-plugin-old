module ActiveScaffold::Activator
  class Base
    delegate :table_name, :class_name, :singular_name, :columns, :updated_at, :to=>"@table"

    def initialize(table, options = {})
      @table = table
      @options = {:targets=>[:model, :controller, :routes]}.merge(options)
      @updated = false
    end

    def construct
      each_targets do |target|
        send("generate_#{ target }")
      end
    end

    def destruct
      each_targets do |target|
        send("destroy_#{ target }")
      end
    end

    private
      def each_targets(&block)
        @options[:targets].each do |target|
          block.call(target)
        end
      end

      def generate_routes
        reset_routes
      end

      def destroy_routes
        reset_routes
      end

      def reset_routes
        if updated?
          Togodb.logger.info "reset routing"
          ActionController::Routing.use_controllers! nil
          ActionController::Routing.possible_controllers
        end
      end

      def updating(condition = true, &block)
        if condition
          block.call if block
          @updated = true
        end
      end

      def updated?
        @updated
      end

      def generate_model
      end

      def generate_controller
      end

      def destroy_model
      end

      def destroy_controller
      end
  end
end

