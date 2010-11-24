module ActiveScaffold::Activator
  class Memory < Base
    private
      def controller_name
        "%sController" % class_name
      end

      def generate_model
        Object.const_get(class_name)
      rescue NameError
        Object.const_set(class_name, Class.new(ActiveRecord::Base))
      end

      def generate_controller
        Object.const_get(controller_name)
      rescue NameError
        Object.const_set(controller_name, Class.new(ActiveRecord::Base))
      end

      def destroy_controller
        updating do
          Object.send :remove_const, controller_name
        end
      rescue NameError
      end
  end
end
