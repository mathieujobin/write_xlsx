# -*- encoding: utf-8 -*-
# frozen_string_literal: true

module Writexlsx
  class Worksheet
    class CellData   # :nodoc:
      include Writexlsx::Utility

      attr_reader :xf

      #
      # attributes for the <cell> element. This is the innermost loop so efficiency is
      # important where possible.
      #
      def cell_attributes(worksheet, row, col) # :nodoc:
        xf_index = xf ? xf.get_xf_index : 0
        attributes = [
          ['r', xl_rowcol_to_cell(row, col)]
        ]

        # Add the cell format index.
        if xf_index != 0
          attributes << ['s', xf_index]
        elsif worksheet.set_rows[row] && worksheet.set_rows[row][1]
          row_xf = worksheet.set_rows[row][1]
          attributes << ['s', row_xf.get_xf_index]
        elsif worksheet.col_formats[col]
          col_xf = worksheet.col_formats[col]
          attributes << ['s', col_xf.get_xf_index]
        end
        attributes
      end

      def display_url_string?
        true
      end
    end

    class NumberCellData < CellData # :nodoc:
      attr_reader :token

      def initialize(num, xf)
        @token = num
        @xf = xf
      end

      def data
        @token
      end

      def write_cell(worksheet, row, col)
        worksheet.writer.tag_elements('c', cell_attributes(worksheet, row, col)) do
          worksheet.write_cell_value(token)
        end
      end
    end

    class StringCellData < CellData # :nodoc:
      attr_reader :token

      def initialize(index, xf)
        @token = index
        @xf = xf
      end

      def data
        { sst_id: token }
      end

      TYPE_STR_ATTRS = %w[t s].freeze
      def write_cell(worksheet, row, col)
        attributes = cell_attributes(worksheet, row, col)
        attributes << TYPE_STR_ATTRS
        worksheet.writer.tag_elements('c', attributes) do
          worksheet.write_cell_value(token)
        end
      end

      def display_url_string?
        false
      end
    end

    class FormulaCellData < CellData # :nodoc:
      attr_reader :token, :result, :range, :link_type, :url

      def initialize(formula, xf, result)
        @token = formula
        @xf = xf
        @result = result
      end

      def data
        @result || 0
      end

      def write_cell(worksheet, row, col)
        truefalse = { 'TRUE' => 1, 'FALSE' => 0 }
        error_code = ['#DIV/0!', '#N/A', '#NAME?', '#NULL!', '#NUM!', '#REF!', '#VALUE!']

        attributes = cell_attributes(worksheet, row, col)
        if @result && !(@result.to_s =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/)
          if truefalse[@result]
            attributes << %w[t b]
            @result = truefalse[@result]
          elsif error_code.include?(@result)
            attributes << %w[t e]
          else
            attributes << %w[t str]
          end
        end
        worksheet.writer.tag_elements('c', attributes) do
          worksheet.write_cell_formula(token)
          worksheet.write_cell_value(result || 0)
        end
      end
    end

    class FormulaArrayCellData < CellData # :nodoc:
      attr_reader :token, :result, :range, :link_type, :url

      def initialize(formula, xf, range, result)
        @token = formula
        @xf = xf
        @range = range
        @result = result
      end

      def data
        @result || 0
      end

      def write_cell(worksheet, row, col)
        worksheet.writer.tag_elements('c', cell_attributes(worksheet, row, col)) do
          worksheet.write_cell_array_formula(token, range)
          worksheet.write_cell_value(result)
        end
      end
    end

    class DynamicFormulaArrayCellData < CellData # :nodoc:
      attr_reader :token, :result, :range, :link_type, :url

      def initialize(formula, xf, range, result)
        @token = formula
        @xf = xf
        @range = range
        @result = result
      end

      def data
        @result || 0
      end

      def write_cell(worksheet, row, col)
        # Add metadata linkage for dynamic array formulas.
        attributes = cell_attributes(worksheet, row, col)
        attributes << %w[cm 1]

        worksheet.writer.tag_elements('c', attributes) do
          worksheet.write_cell_array_formula(token, range)
          worksheet.write_cell_value(result)
        end
      end
    end

    class BooleanCellData < CellData # :nodoc:
      attr_reader :token

      def initialize(val, xf)
        @token = val
        @xf = xf
      end

      def data
        @token
      end

      def write_cell(worksheet, row, col)
        attributes = cell_attributes(worksheet, row, col)

        attributes << %w[t b]
        worksheet.writer.tag_elements('c', attributes) do
          worksheet.write_cell_value(token)
        end
      end
    end

    class BlankCellData < CellData # :nodoc:
      def initialize(xf)
        @xf = xf
      end

      def data
        ''
      end

      def write_cell(worksheet, row, col)
        worksheet.writer.empty_tag('c', cell_attributes(worksheet, row, col))
      end
    end
  end
end
