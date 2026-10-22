# frozen_string_literal: true

module Insights
  # Pie of published OGOs by sourcing flags for Observations insights.
  # Flags can combine; bucket label is the sorted set of matched flags (or None).
  class ObservationsSourcingChart
    SOURCE_DEFS = [
      { key: :feedback_request, label: "Feedback request" },
      { key: :slack, label: "Slack" },
      { key: :consult_og, label: "Consult OG" },
      { key: :observable_moment, label: "Observable moment" },
      { key: :goal, label: "Goal" }
    ].freeze

    NONE_LABEL = "None"

    def self.call(observations)
      new(observations).call
    end

    def self.bucket_label_for(observation)
      new([]).bucket_label_for(observation)
    end

    def initialize(observations)
      @observations = observations
    end

    def call
      counts = Hash.new(0)
      @observations.each do |observation|
        counts[bucket_label_for(observation)] += 1
      end

      total = counts.values.sum
      pie = counts
        .sort_by { |name, count| [-count, name] }
        .map { |name, count| { name: name, y: count } }

      { total: total, pie: pie, counts: counts }
    end

    def bucket_label_for(observation)
      labels = SOURCE_DEFS.filter_map do |defn|
        defn[:label] if source_match?(observation, defn[:key])
      end
      labels.empty? ? NONE_LABEL : labels.join(" + ")
    end

    private

    def source_match?(observation, key)
      case key
      when :feedback_request
        observation.feedback_request_question_id.present?
      when :slack
        observation.slack_sourced?
      when :consult_og
        observation.ogo_consult_sourced?
      when :observable_moment
        observation.observable_moment_id.present?
      when :goal
        observation.goal_id.present?
      else
        false
      end
    end
  end
end
