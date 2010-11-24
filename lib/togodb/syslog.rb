class Togodb::Syslog < ActiveRecord::Base
  set_table_name "togodb_syslogs"

  include Migratable

  column :priority,    :integer, :default=>1
  column :message,     :text
  column :group,       :string
  column :created_at,  :datetime

  EXCEPTION_PRIORITY = 10

  class << self
    def write!(*args)
      error = args.first
      if error.is_a?(Exception)
        hash = exception_to_hash(error)
      else
        hash = NamedOptions.new(args, :message, :priority, :group, :created_at)
      end
      create!(hash)
    end

    def write(*args)
      write!(*args)
    rescue => error
      logger.error "Togodb::Syslog cannot write: [%s] %s\n  args=%s" % [error.class, error.message, args.inspect]
    end

    private
      def exception_pretty_format(error)
        "%s (%s)" % [error.message, error.backtrace[0]]
      end

      def exception_to_hash(error)
        {
          message  => exception_pretty_format(error),
          priority => EXCEPTION_PRIORITY,
        }
      end
  end
end
