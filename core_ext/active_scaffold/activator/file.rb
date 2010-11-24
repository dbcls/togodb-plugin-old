module ActiveScaffold::Activator

  class File < Memory
    AUTO_GENERATED = 'ACTIVE_SCAFFOLD_SCHEMA_AUTO_GENERATED=1'

    private
      def model_file
        "%s/app/models/%s.rb" % [RAILS_ROOT, singular_name]
      end

      def controller_file
        "%s/app/controllers/%s_controller.rb" % [RAILS_ROOT, singular_name]
      end

      def web_service_file
        "%s/app/controllers/%s_web_service.rb" % [RAILS_ROOT, singular_name]
      end

      def can_overwrite?(file)
        ::File.read(file) =~ /^\s*#{ AUTO_GENERATED }\s*$/mo
      end

      def need_write?(file, options = {})
        return true  unless ::File.exist?(file)
        return false if options[:timestamp] and (options[:timestamp] < ::File.mtime(file))
        return can_overwrite?(file)
      end

      def generate_file(file, options = {})
        return false unless need_write?(file, options)
        updating do
          buffer = options[:buffer] || render_template(options[:template])
          ::File.open(file, 'w+'){|f| f.print buffer}
        end
      end

      def render_template(name)
        Togodb.render_template(name, binding)
      end

      def generate_model
        generate_file(model_file, :template=>"model.rb", :timestamp=>updated_at)
      end

      def generate_controller
        generate_file(controller_file,  :template=>"controller.rb",  :timestamp=>updated_at)
        generate_web_service
      end

      def generate_web_service
        generate_file(web_service_file, :template=>"web_service.rb", :timestamp=>updated_at)
      rescue => err
        Togodb.logger.debug err.message
        Togodb.logger.debug err.backtrace.join("\n") rescue nil
        generate_file(web_service_file, :template=>"web_service_not_available.rb", :timestamp=>updated_at)
      end

      def destroy_controller
        ::File.unlink(controller_file) if ::File.exist?(controller_file)
        super
      end
  end
end
