# frozen_string_literal: true

module OneOnOne
  # Compact counts for Start Here from the same priority carousel as the 1:1 Hub page.
  class StartHereHubSummary
    def self.call(organization:, teammate:, one_on_one_link:, viewing_company_teammate:)
      data = PriorityCarouselBuilder.call(
        organization: organization,
        teammate: teammate,
        one_on_one_link: one_on_one_link,
        viewing_company_teammate: viewing_company_teammate
      )
      from_carousel_data(data)
    end

    def self.from_carousel_data(data)
      priorities = data[:priorities] || []
      applicable = priorities.reject { |row| row[:not_applicable] }
      total = applicable.size
      attention = applicable.count { |row| row[:needs_attention] }
      green = total - attention
      top_row = applicable.find { |row| row[:needs_attention] }
      top_title =
        if top_row
          top_row[:title].to_s
        elsif total.positive?
          "Nothing needs attention right now"
        else
          "No priorities apply yet"
        end

      {
        top_title: top_title,
        total_count: total,
        green_count: green,
        needs_attention_count: attention
      }
    end
  end
end
