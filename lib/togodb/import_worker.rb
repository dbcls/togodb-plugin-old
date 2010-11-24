require 'csv'

class Togodb::ImportWorker
  attr_accessor :reader, :header, :counter, :mapping, :entries

  def initialize(reader, *args)
    opts = args.last.is_a?(Hash) ? args.pop["opts"] : {}
    @options = {
      :transaction  => true,
      :null_spacing => true,
      :delete_all   => false,
      :delete_log   => false,
    }.with_indifferent_access.merge(opts)

    buffer   = reader.is_a?(Pathname) ? reader.read : reader.to_s
    buffer   = buffer.gsub(/\0/, " ") # strip null_spacing
    @reader  = CSV::Reader.create(buffer.strip)
    @entries = @reader.entries
    @header  = @entries.shift
    @mapping = hash_of(:records)
    @counter = 0

    Togodb::Syslog(:message=>"Togodb::Import is created with opts: #{@options.inspect}")
  end

  def option?(key)
    @options[key.to_s]
  end

  def column_name(index)
    @mapping[header[index]]
  end

  def row2attributes(row)
    attributes = {}
    row.each_with_index do |col, i|
      next unless column = column_name(i)
      data = col.data.to_s rescue ''
      begin
        attributes[column] = coerce(column, data, attributes)
      rescue Mappings::Error
      end
    end
    return attributes
  end

  def execute_row(row, &block)
    @counter += 1

    attributes  = row2attributes(row)
    record = klass.new(attributes)
    record.save!

    block.call(nil, row) if block
  rescue => err
    attributes ||= {}
    row   = row.map{|i| i.data.to_s rescue nil}
    where = "#{@counter+1}行目"                  # header があるため
    block.call(err, row) if block
  end

  def execute(&block)
    @counter = 0
    Error.delete_all if option?(:delete_log)
    klass.transaction do
      @entries.each {|row| execute_row(row, &block)}
    end
  end

  def progress
    @counter * 100.0 / @entries.size
  rescue
    0
  end
end
