# frozen_string_literal: true

require "ostruct"

class StartHere::Widgets::InsightsObservationsHealthWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "insights_observations_health",
    group: "Insights",
    icon: "bi-heart-pulse",
    selection_title: "Observations Health",
    selection_description: "Observations health across employees.",
    label: "Observations Health",
    path: ->(c) { c.view.organization_observations_health_path(c.organization) },
    description: nil,
    button_label: "Observations Health"
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
    return ActiveSupport::SafeBuffer.new unless org_policy.observations_health?

    stats = ObservationsHealthSpotlightService.new(
      organization: org,
      current_person: person,
      current_company_teammate: ct,
      manage_employment: org_policy.manage_employment?
    ).rows_and_spotlight_for(nil).fetch(:spotlight_stats)

    view.render(
      partial: "shared/observations_health_spotlight_compact",
      locals: { stats: stats },
      formats: [ :html ]
    )
  end
end
