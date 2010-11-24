module Togodb::Generators
  class UnknownOption < RuntimeError; end

  class Base
    delegate :table_name, :class_name, :singular_name, :columns, :setting, :updated_at, :table1, :table2, :to=>"@table"

    def initialize(table, options = {})
      @table   = table
      @options = options
    end

    def construct
      raise NotImplementedError
    end

    def destruct
      raise NotImplementedError
    end

    private
      def reporting(message = nil, &block)
        Togodb.syslog! :message=>message, :priority=>1 if message
        block.call
      rescue => err
        Togodb.syslog(err)
        raise
      end

      def option(key)
        if @options.has_key?(key)
          @options[key]
        else
          raise UnknownOption, "%s:%s" % [self.class.name.demodulize, key]
        end
      end
  end

  class File < Base
    AUTO_GENERATED = 'ACTIVE_SCAFFOLD_SCHEMA_AUTO_GENERATED=1'
    dsl_accessor :path, :default=>proc{|k| raise NotImplementedError, "path is not set for #{k}" }

    def construct
      create_file(path, @options[:buffer] || buffer) if need_write?(path)
    end

    def destruct
      ::File.unlink(path) if ::File.exist?(path)
    end

    private
      def path
        raise NotImplementedError
      end

      def buffer
        raise NotImplementedError
      end

      def can_overwrite?(file = absolute_path)
        return true unless ::File.exist?(file)
        ::File.read(file) =~ /^\s*#{ AUTO_GENERATED }\s*$/mo
      end

      def confirmed?(file = path)
        if @options[:confirm]
          can_overwrite?(file)
        else
          true
        end
      end

      def create_file(path, buffer)
        return nil unless confirmed?(path)

        command = ::File.exist?(path) ? "update" : "install"
        message = "%s: %s" % [command, Togodb.cleanpath(path)]




        return path if @options[:test]
        reporting(message) do
          FileUtils.mkdir_p(::File.dirname(path))
          ::File.open(path, 'w+'){|f| f.print buffer}
        end
        return path
      end

      def delete_file(path)
        return unless ::File.exist?(path)

        message = "delete: %s" % Togodb.cleanpath(path)
        reporting(message) do
          ::File.unlink(path)
        end
        return path
      end
  end

  class Template < File
    dsl_accessor :template, :default=>proc{|k| raise NotImplementedError, "template is not found for #{k}" }

    def construct
      map do |template, target|
        path = realize_path(target)
        create_file(path, render_template(template))
      end
    end

    def destruct
      map do |template, target|
        delete_file(realize_path(target))
      end
    end

    def test
      test_stored = @options[:test]
      @options[:test] = true
      array = construct
      @options[:test] = test_stored
      return array
    end

    private
      def map(&block)
        result = []
        self.class.template.each_pair do |template, target|
          result << block.call(template, target)
        end
        return result
      end

      def render_template(template_name)
        path = "%s/templates/%s" % [Togodb.plugin_dir, template_name]
        Togodb.logger.debug "Togodb: render_template: %s" % path
        source = ::File.read(path)
        ERB.new(source, nil, '-').result(binding)
      end

      def realize_path(target)
        path = instance_eval('"' + target + '"')
        path = ::File.join(RAILS_ROOT, path) unless path[0] == ?/
        return Pathname(path).cleanpath.to_s
      end
  end

  class Model < Template
    template "model.rb" => 'app/models/#{singular_name}.rb'
  end
  
  class Through < Template
    template "through.rb" => 'app/models/#{table_name}.rb'
  end

  class Controller < Template
    template "controller.rb" => 'app/controllers/#{singular_name}_controller.rb'
  end

  class WebService < Template
    template "web_service.rb" => 'app/controllers/#{singular_name}_web_service.rb'
  end

  class WebServiceNotReady < Template
    template "web_service_not_ready.rb" => 'app/controllers/#{singular_name}_web_service.rb'
  end

  class Page < Template
    template "_page_header.rhtml" => 'app/views/#{singular_name}/_page_header.rhtml',
             "_page_footer.rhtml" => 'app/views/#{singular_name}/_page_footer.rhtml',
             "_html_head.rhtml"   => 'app/views/#{singular_name}/_html_head.rhtml'
  end
end

