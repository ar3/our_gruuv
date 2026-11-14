# frozen_string_literal: true

# Widget id kept as admin_value_billing so existing Start Here dashboards keep working.
class StartHere::Widgets::AdminValueBillingWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "admin_value_billing",
    group: "Admin",
    icon: "bi-graph-up-arrow",
    selection_title: "Value",
    selection_description: "Transparent value delivered.",
    label: "Value",
    path: ->(c) { c.view.organization_value_path(c.organization) },
    description: "Transparent value delivered.",
    button_label: "Value"
  }.freeze
end
