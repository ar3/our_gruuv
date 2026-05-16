# frozen_string_literal: true

module Insights
  module OgScorecard
    # Central registry of OG Scorecard metrics (metadata + defaults). Threshold values live in DB.
    class MetricRegistry
      Entry = Data.define(:key, :label, :direction, :supports_percent, :group)

      ENTRIES = [
        Entry.new(
          key: 'active_teammates',
          label: 'Number of active teammates',
          direction: :more,
          supports_percent: true,
          group: 'Teammates'
        ),
        Entry.new(
          key: 'unique_ogo_publishers',
          label: 'Number of unique teammates that published an OGO',
          direction: :more,
          supports_percent: true,
          group: 'Observations'
        ),
        Entry.new(
          key: 'unique_ogo_observees',
          label: 'Number of unique teammates named as observees in an OGO',
          direction: :more,
          supports_percent: true,
          group: 'Observations'
        )
      ].freeze

      class << self
        def all
          ENTRIES
        end

        def keys
          ENTRIES.map(&:key)
        end

        def key?(key)
          keys.include?(key.to_s)
        end

        def find(key)
          ENTRIES.find { |e| e.key == key.to_s }
        end

        def grouped
          ENTRIES.group_by(&:group).map { |title, rows| { title: title, entries: rows } }
        end
      end
    end
  end
end
