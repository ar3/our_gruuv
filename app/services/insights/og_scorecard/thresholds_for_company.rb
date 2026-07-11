# frozen_string_literal: true

module Insights
  module OgScorecard
    class ThresholdsForCompany
      def self.call(company)
        new(company).call
      end

      def initialize(company)
        @company = company
      end

      def call
        prune_stale_threshold_rows!

        records = OgScorecardMetricThreshold.for_company(company).index_by(&:metric_key)
        OgScorecard::MetricRegistry.keys.index_with do |key|
          record = records[key]
          next default_threshold unless record

          {
            yellow: record.yellow_threshold,
            green: record.green_threshold,
            mode: record.threshold_mode,
            configured?: record.configured?
          }
        end
      end

      private

      attr_reader :company

      def prune_stale_threshold_rows!
        OgScorecardMetricThreshold
          .for_company(company)
          .where.not(metric_key: OgScorecard::MetricRegistry.keys)
          .delete_all
      end

      def default_threshold
        { yellow: nil, green: nil, mode: 'absolute', configured?: false }
      end
    end
  end
end
