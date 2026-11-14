# frozen_string_literal: true

class StartHere::Widgets::AdminBillingWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "admin_billing",
    group: "Admin",
    icon: "bi-receipt",
    selection_title: "Billing",
    selection_description: "Value-based PEPM and invoices.",
    label: "Billing",
    path: ->(c) { c.view.organization_billing_path(c.organization) },
    description: "Value-based PEPM and invoices.",
    button_label: "Billing"
  }.freeze
end
