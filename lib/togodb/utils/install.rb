require 'pathname'
require 'fileutils'

class Togodb::Utils::Install
  def initialize(path, buffer)
    @path   = Pathname(path)
    @buffer = buffer.to_s
  end

  def execute
    create_directory
    write_data
  end

  private
    def create_directory
      dir = @path.parent
      unless dir.exist?
        log "create directory: #{dir}"
        FileUtils.mkdir_p(dir)
      end
    end

    def write_data
      log "install file: #{@path}"
      @path.open("w+"){|f| f.print @buffer}
    end

    def log(*args)
      Togodb::Syslog.write(*args)
    end
end
