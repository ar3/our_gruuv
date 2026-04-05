# frozen_string_literal: true

class StartHere::Widgets::BetaDigestWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "beta_digest",
    group: "Beta",
    icon: "bi-bell",
    selection_title: "Daily / Weekly Digest",
    selection_description: "Digest notification preferences.",
    label: "Daily / Weekly Digest",
    path: ->(c) { c.view.edit_organization_digest_path(c.organization) },
    description: "Digest notification preferences.",
    button_label: "Digest settings"
  }.freeze
end
