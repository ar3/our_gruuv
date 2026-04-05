# frozen_string_literal: true

class StartHere::Widgets::AboutCheckInReviewWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "about_check_in_review",
    group: "About Me",
    icon: "bi-check-circle",
    selection_title: "Check-In Review",
    selection_description: "Review and finalize your check-in.",
    label: "Check-In Review",
    path: ->(c) { c.view.organization_company_teammate_finalization_path(c.organization, c.company_teammate) },
    description: "Review and finalize your check-in.",
    button_label: "Check-In Review"
  }.freeze
end
