# frozen_string_literal: true

class StartHere::Widgets::AboutAcknowledgementWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "about_acknowledgement",
    group: "About Me",
    icon: "bi-clock-history",
    selection_title: "Acknowledgement",
    selection_description: "Acknowledgement and audit trail for your employment record.",
    label: "Acknowledgement",
    path: ->(c) { c.view.audit_organization_employee_path(c.organization, c.company_teammate) },
    description: "Acknowledgement and audit trail for your employment record.",
    button_label: "Acknowledgement"
  }.freeze
end
