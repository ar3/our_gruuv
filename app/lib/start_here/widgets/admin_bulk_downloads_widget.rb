# frozen_string_literal: true

class StartHere::Widgets::AdminBulkDownloadsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "admin_bulk_downloads",
    group: "Admin",
    icon: "bi-download",
    selection_title: "Bulk Downloads",
    selection_description: "Bulk downloads.",
    label: "Bulk Downloads",
    path: ->(c) { c.view.organization_bulk_downloads_path(c.organization) },
    description: "Bulk downloads.",
    button_label: "Bulk Downloads"
  }.freeze
end
