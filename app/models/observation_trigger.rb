class ObservationTrigger < ApplicationRecord
  has_many :observations, dependent: :nullify
  
  validates :trigger_source, presence: true
  validates :trigger_type, presence: true
  
  # Instance methods
  def formatted_trigger_data
    return "No trigger data" if trigger_data.blank? || trigger_data.nil?
    
    # Format JSONB data as readable markdown
    lines = []
    trigger_data.each do |key, value|
      formatted_key = key.to_s.humanize
      formatted_value = format_value(value)
      lines << "**#{formatted_key}**: #{formatted_value}"
    end
    lines.join("\n\n")
  end

  def tooltip_trigger_data_html
    return "No trigger data" if trigger_data.blank?

    trigger_data.map do |key, value|
      "#{ERB::Util.html_escape(key.to_s.humanize)}: #{ERB::Util.html_escape(format_value(value))}"
    end.join("<br>")
  end

  def ogo_source_search?
    trigger_type == "ogo_source_search"
  end

  def slack_message_permalink
    return nil if trigger_data.blank?

    trigger_data["permalink"].presence || trigger_data[:permalink].presence
  end

  # Provider run id lives in trigger_data so Zoom/Meet/etc. can share this pattern
  # without new columns on observations. See docs/ogo-creation-attribution.md
  def source_slack_search
    return nil unless trigger_source == "slack" && ogo_source_search?

    search_id = trigger_data&.dig("possible_observation_slack_search_id").presence ||
                trigger_data&.dig(:possible_observation_slack_search_id).presence
    return nil if search_id.blank?

    PossibleObservationSlackSearch.find_by(id: search_id)
  end
  
  def display_text
    if ogo_source_search?
      case trigger_source
      when "slack"
        "a Slack Find-Missing-OGOs search"
      when "ogo_consult"
        "a Consult OG to Find OGOs"
      else
        "an OG source search"
      end
    else
      "#{trigger_source.humanize}'s #{trigger_type.humanize}"
    end
  end
  
  private
  
  def format_value(value)
    case value
    when Hash
      value.map { |k, v| "#{k.to_s.humanize}: #{format_value(v)}" }.join(", ")
    when Array
      value.map { |v| format_value(v) }.join(", ")
    when Time, DateTime, ActiveSupport::TimeWithZone
      value.strftime('%B %d, %Y at %l:%M %p')
    when Date
      value.strftime('%B %d, %Y')
    when String
      # Try to parse as date/time if it looks like one
      if value.match?(/^\d{4}-\d{2}-\d{2}/)
        begin
          parsed = Time.parse(value)
          parsed.strftime('%B %d, %Y at %l:%M %p')
        rescue
          value
        end
      else
        value
      end
    when nil
      "N/A"
    else
      value.to_s
    end
  end
end

