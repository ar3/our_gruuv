# frozen_string_literal: true

require "ostruct"

class StartHere::Widgets::InsightsMilestonesHealthWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "insights_milestones_health",
    group: "Insights",
    icon: "bi-heart-pulse",
    selection_title: "Milestones Health",
    selection_description: "Milestones health across employees.",
    label: "Milestones Health",
    path: ->(c) { c.view.organization_milestones_health_path(c.organization) },
    description: nil,
    button_label: "Milestones Health"
  }.freeze

  def dashboard_content
    person = context.person
    ct = context.company_teammate
    if ct.blank? && view.controller.respond_to?(:current_company_teammate)
      ct = view.controller.current_company_teammate
    end
    return ActiveSupport::SafeBuffer.new if person.blank? || ct.blank?

    org = ct.organization
    return ActiveSupport::SafeBuffer.new if org.blank?

    ctrl = view.controller
    imp = ctrl.respond_to?(:impersonating_teammate) ? ctrl.impersonating_teammate : nil
    puser = OpenStruct.new(user: ct, impersonating_teammate: imp)
    org_policy = OrganizationPolicy.new(puser, org)
    return ActiveSupport::SafeBuffer.new unless org_policy.milestones_health?

    stats = MilestonesHealthSpotlightService.new(
      organization: org,
      current_person: person,
      current_company_teammate: ct,
      manage_employment: org_policy.manage_employment?
    ).compact_spotlight_stats(nil)

    view.render(
      partial: "shared/milestones_health_spotlight_compact",
      locals: { stats: stats },
      formats: [ :html ]
    )
  end
end
