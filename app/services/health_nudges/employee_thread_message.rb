# frozen_string_literal: true

module HealthNudges
  # Slack thread reply for one employee on a health nudge.
  class EmployeeThreadMessage
    def initialize(entry:)
      @entry = entry.symbolize_keys
    end

    def fallback_text
      text = "#{@entry[:name]} ... #{@entry[:status_label]}: #{@entry[:detail]}"
      text = "#{text} #{@entry[:action_url]}" if @entry[:action_url].present?
      text
    end

    def slack_blocks
      text = [
        "*#{@entry[:name]}* ... #{@entry[:status_emoji]} *#{@entry[:status_label]}*",
        @entry[:detail].to_s
      ].join("\n")

      section = {
        type: "section",
        text: {
          type: "mrkdwn",
          text: text
        }
      }

      if @entry[:profile_image_url].present?
        section[:accessory] = {
          type: "image",
          image_url: @entry[:profile_image_url],
          alt_text: "#{@entry[:name]} profile image"
        }
      end

      blocks = [ section ]
      if @entry[:action_url].present?
        blocks << {
          type: "actions",
          elements: [
            {
              type: "button",
              text: {
                type: "plain_text",
                text: button_label,
                emoji: true
              },
              url: @entry[:action_url],
              action_id: "health_nudge_employee_destination"
            }
          ]
        }
      end
      blocks
    end

    private

    def button_label
      label = @entry[:action_button_label].presence || "Go to #{@entry[:name]}'s One Thing Page"
      label.to_s.truncate(75, omission: "…")
    end
  end
end
