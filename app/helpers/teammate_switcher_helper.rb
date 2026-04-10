# frozen_string_literal: true

module TeammateSwitcherHelper
  # Browser tab title aligned with header UX: "Casual Name - Page Label"
  def teammate_context_page_title(teammate, page_label)
    "#{teammate.person.casual_name} - #{page_label}"
  end
end
