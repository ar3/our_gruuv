# frozen_string_literal: true

# Title minor levels 1–3 (the segment after the dot in position levels like 2.1).
# Used for eligibility default summaries and anywhere the same tier language is needed.
module PositionEligibilityMinorLevels
  VALID = (1..3).freeze

  # Core tier copy (without the trailing "within the title" phrase).
  TIER_DESCRIPTION = {
    1 => "Emerging / starting salary. Coming from different or less responsibility than what is expected",
    2 => "Established / solid experience",
    3 => "Elite / mastery of what is expected"
  }.freeze

  # Card header matching position notation (e.g. Positions *.1).
  def self.card_header_title(minor)
    validate_minor!(minor)
    "Positions *.#{minor}"
  end

  # Subtitle text under the summary card header (includes "within the title").
  def self.header_caption_within_title(minor)
    validate_minor!(minor)
    "#{TIER_DESCRIPTION.fetch(minor)} within the title"
  end

  # Short tier copy for tooltips and inline help (nil if minor is not 1–3).
  def self.tier_description(minor)
    TIER_DESCRIPTION[minor] if minor.is_a?(Integer) && VALID.cover?(minor)
  end

  def self.validate_minor!(minor)
    return if VALID.cover?(minor)

    raise ArgumentError, "minor must be 1, 2, or 3 (got #{minor.inspect})"
  end
end
