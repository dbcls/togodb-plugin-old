require 'pathname'
require 'csv'
require 'kconv'

include Togodb::Utils::Encoding

module Togodb::Utils::Exports

  module Generates
    module CsvMem
      def generate
        CSV::Writer.generate(@buffer) do |csv|
          csv << column_labels(@data[0]) unless @data.empty?
          @data.each do |record|
            csv << generate_record(record)
          end
        end
      end

      def generate_record(record)
        raise NotImplementedError, "Subclass responsibility"
      end
    end
  end

  module RecordConvertors
    class Base
      delegate :id, :to=>"@record"

      def initialize(record)
        @record = record
      end

      def execute(*keys)
        keys.flatten!
        keys.map do |key|
          if key.blank?
            nil
          else
            receiver_for(key).__send__(key)
          end
        end
      end

      private
        def receiver_for(key)
          respond_to?(key) ? self : @record
        end
    end
  end

  module Writers
    class Base
      def initialize(data, output, options = {})
        @data    = data
        @output  = output.is_a?(Pathname) ? output : Pathname(output.to_s)
        @options = options
      end

      def clear
        @buffer = ''
        @output.unlink if @output.exist?
      end

      def generate
        @buffer = @data
      end

      def convert
        if @options[:encoding] == :sjis
          @buffer = to_sjis(@buffer)
        end
      end

      def write
        @output.open('w+'){|f| f.print @buffer}
      end

      def execute
        clear
        generate
        convert
        write
      end
    end

    class CsvMem < Base
      include Generates::CsvMem

      dsl_accessor :record_converter, RecordConvertors::Base, :instance=>true

      def valid_columns(record)
        unless @valid_columns
          togodb_table = Togodb::Table.find_by_name(record.class.table_name)
          @valid_columns = Togodb::Column.find(:all, :conditions => ["table_id = ? AND dl_column_order > 0", togodb_table.id], :order => "dl_column_order asc")
        end

        @valid_columns
      end

      def generate_record(record)
        record_converter.new(record).execute(valid_columns(record).map(&:name))
      end

      def column_labels(record)
        column_labels = []

        togodb_table = Togodb::Table.find_by_name(record.class.table_name)
        unless togodb_table.nil?
          valid_columns(record).each {|column|
            if column.label.nil?
              column_labels << ''
            else
              column_labels << column.label
            end
          }
        end

        column_labels
      end
    end

    class Csv < CsvMem
      def generate
        CSV.open(@output, 'w') do |writer|
          unless @data.empty?
            if @options[:encoding] == :sjis
              writer << to_sjis(column_labels(@data[0]))
            else
              writer << column_labels(@data[0])
            end
          end

          @data.each do |record|
            if @options[:encoding] == :sjis
              writer << to_sjis(generate_record(record))
            else
              writer << generate_record(record)
            end
          end
        end
      end

      def convert
        # nothing to do
      end

      def write
        # nothing to do
      end

      private

      def to_sjis(ary)
        ary.map { |v| utf8tosjis(v) }
      end
    end
  end

  class Table
    def initialize(record)
      @table = record
    end

    def write_as(writer_class, pathname)
      if writer_class.is_a?(Symbol)
        writer_class = search_writer_for(writer_class)
      end
      data = @table.active_record.find(:all)
      writer_class.new(data, pathname).execute
    end

    private
      def search_writer_for(type)
        "Togodb::Utils::Exports::Writers::#{type.to_s.classify}".constantize
      end
  end

end
