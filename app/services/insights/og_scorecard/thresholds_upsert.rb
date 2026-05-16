# frozen_string_literal: true

module Insights
  module OgScorecard
    class ThresholdsUpsert
      def self.call(company:, params:)
        new(company: company, params: params).call
      end

      def initialize(company:, params:)
        @company = company
        @params = params || {}
      end

      def call
        MetricRegistry.keys.each do |metric_key|
          row = params[metric_key] || params[metric_key.to_sym]
          next if row.blank?

          record = OgScorecardMetricThreshold.find_or_initialize_by(company: company, metric_key: metric_key)
          record.threshold_mode = row[:threshold_mode].presence || row['threshold_mode'].presence || 'absolute'
          record.yellow_threshold = parse_decimal(row[:yellow_threshold] || row['yellow_threshold'])
          record.green_threshold = parse_decimal(row[:green_threshold] || row['green_threshold'])
          record.save!
        end
      end

      private

      attr_reader :company, :params

      def parse_decimal(raw)
        return nil if raw.blank?

        BigDecimal(raw.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
