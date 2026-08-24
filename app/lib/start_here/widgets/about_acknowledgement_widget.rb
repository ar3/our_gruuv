# frozen_string_literal: true

class StartHere::Widgets::AboutAcknowledgementWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "about_acknowledgement",
    group: "About Me",
    icon: "bi-clock-history",
    selection_title: "Acknowledgement",
    selection_description: "Acknowledge finalized check-in ratings with Agree or Disagree.",
    label: "Acknowledgement",
    path: ->(c) { c.view.acknowledge_organization_company_teammate_check_ins_path(c.organization, c.company_teammate) },
    description: "Acknowledge and agree or disagree with finalized check-in ratings.",
    button_label: "Acknowledgement"
  }.freeze
end
