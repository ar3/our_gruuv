# frozen_string_literal: true

class StartHere::Widgets::AdminBulkEventsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "admin_bulk_events",
    group: "Admin",
    icon: "bi-upload",
    selection_title: "Bulk Events",
    selection_description: "Bulk sync events.",
    label: "Bulk Events",
    path: ->(c) { c.view.organization_bulk_sync_events_path(c.organization) },
    description: "Bulk sync events.",
    button_label: "Bulk Events"
  }.freeze
end
