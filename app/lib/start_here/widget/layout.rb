# frozen_string_literal: true

module StartHere
  module Widget
    # Order of groups on the “Add new widgets” panel (top to bottom).
    # Use quoted strings — %w[] splits on spaces, so %w[About Me] is two entries, not one.
    module Layout
      ADD_PANEL_GROUP_ORDER = [
        "About Me",
        "Observations (OGO)",
        "Directory",
        "Get things done",
        "Abilities and milestones",
        "Insights",
        "Huddles",
        "Kudos Center",
        "Admin",
        "Beta",
        "Feedback",
      ].freeze
    end
  end
end
