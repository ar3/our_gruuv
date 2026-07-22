# frozen_string_literal: true

require "ostruct"

class StartHere::Widgets::ProtectFlowWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "protect_flow",
    group: "Directory",
    icon: "bi-shield-check",
    selection_title: "Protect Flow",
    selection_description: "This week’s highest-leverage actions across your direct reports.",
    label: "Protect Flow",
    path: ->(c) { c.view.organization_protect_flow_path(c.organization) },
    description: "Protect flow — stale clarity kills it. About 30 minutes per person this week.",
    button_label: "Open Protect Flow"
  }.freeze

  def active?
    ct = context.company_teammate
    return false if ct.blank?
    return false unless ct.has_direct_reports?

    org = context.organization || ct.organization
    return false if org.blank?

    ctrl = view.controller
    imp = ctrl.respond_to?(:impersonating_teammate) ? ctrl.impersonating_teammate : nil
    puser = OpenStruct.new(user: ct, impersonating_teammate: imp)
    OrganizationPolicy.new(puser, org).protect_flow?
  rescue StandardError
    false
  end
end
