# frozen_string_literal: true

module HealthNudges
  # Non-LLM plain-text main body for Overall Health nudges (char-budgeted for Slack).
  class SuggestedBody
    # Slack section mrkdwn hard limit is 3000; leave headroom for safety.
    MAX_CHARS = 2800

    def self.call(message:, people: [])
      new(message: message, people: people).call
    end

    def initialize(message:, people: [])
      @message = message
      @people = Array(people)
    end

    def call
      header = [
        @message.suggested_greeting_line,
        "",
        @message.suggested_summary_line_plain,
        "",
        @message.suggested_closing_line
      ].join("\n")

      employee_block = employee_sentences
      body =
        if employee_block.present?
          "#{header}\n\n#{employee_block}"
        else
          header
        end

      truncate_to_limit(body)
    end

    private

    def employee_sentences
      ranked = @people.sort_by do |person|
        [
          EngagementHealth.status_severity_rank(person[:worst_status]),
          person[:name].to_s.downcase
        ]
      end

      lines = []
      ranked.each do |person|
        sentence = sentence_for(person)
        next if sentence.blank?

        candidate = lines.empty? ? sentence : "#{lines.join("\n")}\n#{sentence}"
        # Prefer fitting as many people as possible under MAX_CHARS with header reserved.
        break if candidate.length > (MAX_CHARS - 400) && lines.any?

        lines << sentence
      end
      lines.join("\n")
    end

    def sentence_for(person)
      name = person[:name].presence || "Teammate"
      attention = Array(person[:attention_items]).reject { |a| a[:category].to_s == "pending_health" }
      if attention.empty?
        return "#{name}: all health signals look steady — keep the cadence going."
      end

      bits = attention.first(2).map do |item|
        label = item[:short_title].presence || item[:title]
        status = item[:status_label].presence || EngagementHealth::STATUS_LABELS[item[:status]]
        "#{label} (#{status})"
      end
      extra = attention.size - bits.size
      tail = extra.positive? ? " +#{extra} more" : ""
      "#{name}: focus on #{bits.join(' and ')}#{tail}."
    end

    def truncate_to_limit(body)
      return body if body.length <= MAX_CHARS

      trimmed = body[0, MAX_CHARS - 20]
      cut = trimmed.rindex("\n") || (MAX_CHARS - 20)
      "#{trimmed[0, cut].rstrip}\n…(trimmed for Slack)"
    end
  end
end
