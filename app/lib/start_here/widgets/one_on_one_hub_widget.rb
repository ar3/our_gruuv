# frozen_string_literal: true

require "ostruct"

class StartHere::Widgets::OneOnOneHubWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "one_on_one_hub",
    group: "About Me",
    icon: "bi-link-45deg",
    selection_title: "1:1 Hub",
    selection_description: "Top priority from your 1:1 Hub and how many items are healthy vs need attention.",
    label: "1:1 Hub",
    path: ->(c) { c.view.organization_company_teammate_one_on_one_link_path(c.organization, c.company_teammate) },
    description: nil,
    button_label: "Open 1:1 Hub"
  }.freeze

  def active?
    ct = context.company_teammate
    return false if ct.blank?

    org = ct.organization
    return false if org.blank?

    ctrl = view.controller
    imp = ctrl.respond_to?(:impersonating_teammate) ? ctrl.impersonating_teammate : nil
    puser = OpenStruct.new(user: ct, impersonating_teammate: imp)
    link = ct.one_on_one_link || OneOnOneLink.new(teammate: ct)
    OneOnOneLinkPolicy.new(puser, link).show?
  rescue StandardError
    false
  end

  def dashboard_content
    ct = context.company_teammate
    if ct.blank? && view.controller.respond_to?(:current_company_teammate)
      ct = view.controller.current_company_teammate
    end
    return ActiveSupport::SafeBuffer.new if ct.blank?

    org = ct.organization
    return ActiveSupport::SafeBuffer.new if org.blank?

    ctrl = view.controller
    imp = ctrl.respond_to?(:impersonating_teammate) ? ctrl.impersonating_teammate : nil
    puser = OpenStruct.new(user: ct, impersonating_teammate: imp)
    link = ct.one_on_one_link || OneOnOneLink.new(teammate: ct)
    return ActiveSupport::SafeBuffer.new unless OneOnOneLinkPolicy.new(puser, link).show?

    summary = OneOnOne::StartHereHubSummary.call(
      organization: org,
      teammate: ct,
      one_on_one_link: link,
      viewing_company_teammate: ct
    )

    view.render(
      partial: "shared/one_on_one_hub_start_here_compact",
      locals: { summary: summary },
      formats: [ :html ]
    )
  end
end
