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
    lines.join("\n")
  end
  
  def display_text
    "#{trigger_source.humanize}'s #{trigger_type.humanize}"
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

