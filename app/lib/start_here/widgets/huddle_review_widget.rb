# frozen_string_literal: true

class StartHere::Widgets::HuddleReviewWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "huddle_review",
    group: "Huddles",
    icon: "bi-graph-up",
    selection_title: "Huddle Review",
    selection_description: "Review huddle activity for the organization.",
    label: "Huddle Review",
    path: ->(c) { c.view.huddles_review_organization_path(c.organization) },
    description: "Review huddle activity for the organization.",
    button_label: "Huddle Review"
  }.freeze
end
