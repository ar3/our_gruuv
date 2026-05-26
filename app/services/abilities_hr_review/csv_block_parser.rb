# frozen_string_literal: true

require 'csv'

module AbilitiesHrReview
  # Parses HR-style CSV: assignment title on its own row; subsequent rows are abilities until blank.
  class CsvBlockParser
    attr_reader :errors, :warnings, :ability_rows

    def initialize(file_content)
      @file_content = file_content.to_s
      @errors = []
      @warnings = []
      @ability_rows = []
    end

    def parse
      if @file_content.blank?
        @errors << 'File content is required'
        return false
      end

      table = CSV.parse(@file_content, headers: true, encoding: 'UTF-8')
      unless table.headers
        @errors << 'CSV must include a header row'
        return false
      end

      headers_map = HeaderMap.new(table.headers)
      unless headers_map.valid?
        @errors.concat(headers_map.errors)
        return false
      end

      current_assignment = nil
      table.each.with_index(2) do |row, csv_row_number|
        cells = row.to_h.transform_keys { |k| k.to_s.strip }
        assignment_val = value(cells, headers_map.assignment_key)
        name_val = value(cells, headers_map.ability_name_key)
        desc_val = value(cells, headers_map.description_key)
        milestone_vals = (1..5).map { |n| value(cells, headers_map.milestone_key(n)) }
        ability_ms_val = value(cells, headers_map.ability_milestone_key)

        next if row_blank?(assignment_val, name_val, desc_val, milestone_vals, ability_ms_val)

        assignment_only = assignment_val.present? &&
                           name_val.blank? &&
                           desc_val.blank? &&
                           milestone_vals.all?(&:blank?) &&
                           ability_ms_val.blank?

        if assignment_only
          current_assignment = assignment_val.strip
          next
        end

        ability_like = name_val.present? || desc_val.present? || milestone_vals.any?(&:present?)
        unless ability_like
          @errors << "Row #{csv_row_number}: could not classify row (expected assignment header or ability data)."
          next
        end

        if current_assignment.blank?
          @warnings << "Row #{csv_row_number}: ability row appears before any assignment header."
        end

        @ability_rows << {
          'source_csv_row' => csv_row_number,
          'assignment_raw' => current_assignment,
          'ability_name' => name_val.to_s.strip,
          'description_raw' => desc_val.to_s,
          'milestone_1_raw' => milestone_vals[0].to_s,
          'milestone_2_raw' => milestone_vals[1].to_s,
          'milestone_3_raw' => milestone_vals[2].to_s,
          'milestone_4_raw' => milestone_vals[3].to_s,
          'milestone_5_raw' => milestone_vals[4].to_s,
          'ability_milestone_raw' => ability_ms_val.to_s
        }
      end

      if @ability_rows.empty?
        @errors << 'No ability rows found. Check assignment/ability rows and column headers.'
        return false
      end

      true
    rescue CSV::MalformedCSVError => e
      @errors << "Malformed CSV: #{e.message}"
      false
    end

    private

    def value(cells, header_key)
      return '' if header_key.blank?

      cells[header_key].to_s
    end

    def row_blank?(assignment_val, name_val, desc_val, milestone_vals, ability_ms_val)
      assignment_val.blank? &&
        name_val.blank? &&
        desc_val.blank? &&
        milestone_vals.all?(&:blank?) &&
        ability_ms_val.blank?
    end

    # Maps human headers to canonical keys used in CSV rows
    class HeaderMap
      attr_reader :assignment_key, :ability_name_key, :description_key, :ability_milestone_key,
                  :milestone_keys, :errors

      def initialize(headers)
        @errors = []
        stripped = headers.compact.map { |h| h.to_s.strip }.reject(&:blank?)

        @assignment_key = find_first(stripped, [/\Aassignment(\s+name|\s+title)?\z/i, /\Aassignment\z/i])
        @ability_name_key = find_ability_name(stripped)
        @description_key = find_first(stripped, [/\Adescription\z/i])
        @ability_milestone_key = find_first(stripped, [/ability\s*milestone/i, /ability_milestone/i])

        @milestone_keys = (1..5).map do |n|
          find_first(stripped, [/\Amilestone\s*#{n}\s*\z/i])
        end

        @milestone_keys.each_with_index do |key, idx|
          @errors << "Missing header for Milestone #{idx + 1}" if key.blank?
        end

        @errors << 'Missing Assignment column' if @assignment_key.blank?
        @errors << 'Missing Ability name column (Ability, Ability Name, or Name)' if @ability_name_key.blank?
        @errors << 'Missing Description column' if @description_key.blank?
      end

      def milestone_key(n)
        @milestone_keys[n - 1]
      end

      def valid?
        @errors.empty?
      end

      private

      def find_first(stripped, patterns)
        stripped.find { |h| patterns.any? { |p| h.match?(p) } }
      end

      def find_ability_name(stripped)
        prefer = find_first(stripped, [/\Aability\s*name\z/i, /\Aability\z/i])
        return prefer if prefer.present?

        find_first(stripped, [/\Aname\z/i])
      end
    end
  end
end
