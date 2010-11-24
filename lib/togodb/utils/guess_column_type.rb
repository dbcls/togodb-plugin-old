require 'csv'
require 'pathname'

module Togodb::Utils
  class GuessColumnType
    NUM_CHECK_RECORDS = 100000

    class DataIsEmpty < RuntimeError; end
    class ColumnType
      class Fixed < RuntimeError; end

      module Generalities
        class Text ; end
        class String < Text; end
        class Time < String; end
        class Date < Time; end
        class Float < String; end
        class Decimal < Float; end
        class Integer < Decimal; end
        class Boolean < Integer; end
      end

      def initialize
        @generality = nil
      end

      def <<(data)
        return seems Generalities::Text if data.size > 255

        case data.to_s
        when '0', '1'
          seems Generalities::Boolean

        when /\A-?\d*\.\d+\Z/
          seems Generalities::Float

        when /\A-?\d+\Z/
          seems Generalities::Integer

        when %r[^(\d){4}[-/](\d){1,2}[-/](\d){1,2}$]
          seems Generalities::Date

        when /\n/
          seems Generalities::Text

        else
          seems Generalities::String
        end
      end

      def type
        if @generality
          @generality.name.split(/::/).last.downcase
        else
          "text"
        end
      end

      private
        def current
          @generality
        end

        def seems(type)
          if current
            update_generality(current, type)
          else
            @generality = type
          end
#-->          raise Fixed if current == Generalities::Text
        end

        def update_generality(current, type)
          if type <= current
            # nop
          elsif current < type
            # tipe is more general than current
            @generality = type
          else
            # find an ancestor which these both types shares together
          end
        end

    end

    def initialize(file, options = {})
      @file    = file
      @options = options

      raise DataIsEmpty unless @file

      if header?
        @header = first_entry
        @column_size = @header.size
      else
        @header = nil
        @column_size = first_entry.size
      end

      if @options[:fs]
        @fs = @options[:fs]
      else
        @fs = ","
      end
    end

    # returns: ["string", "integer", ...] where types are kind of AR::ColumnType
    def execute(column_indexes = nil)
#-->      return (0...@column_size).map{|i| guess_at(i)}
      guess(column_indexes).map{|t| t.type}
    end

    private
      def header?
        @options[:header]
      end

      def guess(column_indexes = nil)
        if column_indexes.nil?
          col_ids = Array.new(@column_size) {|i| i}
        else
          col_ids = column_indexes
        end

        row_id = 0
        column_types = Array.new(col_ids.size).collect {ColumnType.new}

        begin
          require 'csvscan'
          open(@file) {|io|
            CSVScan.scan(io) {|row|
              if header? && row_id == 0
                row_id = 1
                next
              end

              col_ids.each_with_index {|col_id, i|
                data = row[col_id].to_s
                column_types[i] << data
              }

              row_id += 1
              break if row_id == NUM_CHECK_RECORDS
            }
          }
        rescue LoadError => e
          CSV.open(@file, 'r', @fs) {|row|
            if header? && row_id == 0
              row_id = 1
              next
            end

            col_ids.each_with_index {|col_id, i|
              data = row[col_id].to_s
              column_types[i] << data
            }

            row_id += 1
            break if row_id == NUM_CHECK_RECORDS
          }
        end

        column_types
      end

      def guess_at(column_index)
        column_type = ColumnType.new
        row_id = 0
        begin
          require 'csvscan'
          open(@file) {|io|
            CSVScan.scan(io) {|row|
              next if header? && row_id == 0

              data = row[column_index].to_s
              column_type << data

              row_id += 1
              break if row_id == NUM_CHECK_RECORDS
            }
          }
        rescue LoadError => e
          CSV.open(@file, 'r', @fs) {|row|
            next if header? && row_id == 1

            data = row[column_index].to_s
            column_type << data

            row_id += 1
            break if row_id == NUM_CHECK_RECORDS
          }
        end
        return column_type.type
      rescue ColumnType::Fixed
        return column_type.type
      end

=begin
      def entries
        @entries ||= generate_entries
      end
=end

=begin
      def column_size
#-->        (header || entries.first).size
        header? ? @header.size : first_entry.size
      end
=end

=begin
      def header
        if header?
#-->          entries               # ensure @header is initialized
          @header = first_entry
          return @header
        else
          return nil
        end
      end
=end

=begin
      def generate_entries
        file  = @file.is_a?(Pathname) ? @file.read : @file
        array = CSV::Reader.create(file).entries
        @header = array.shift if header?
        raise DataIsEmpty if array.empty? or !array.first or array.first.empty?
        return array
      end
=end

      def first_entry
        entry = []
        begin
          require 'csvscan'
          open(@file) {|io|
            CSVScan.scan(io) {|row|
              entry = row
              break
            }
          }
        rescue LoadError => e
          CSV.open(@file, 'r', @fs) {|row|
            entry = row
            break
          }
        end

        entry
      end
  end
end

