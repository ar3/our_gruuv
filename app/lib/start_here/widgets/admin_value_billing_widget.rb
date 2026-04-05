# frozen_string_literal: true

class StartHere::Widgets::AdminValueBillingWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "admin_value_billing",
    group: "Admin",
    icon: "bi-cash-coin",
    selection_title: "Value / Billing",
    selection_description: "Billing and value.",
    label: "Value / Billing",
    path: ->(c) { c.view.organization_value_billing_path(c.organization) },
    description: "Billing and value.",
    button_label: "Value / Billing"
  }.freeze
end
