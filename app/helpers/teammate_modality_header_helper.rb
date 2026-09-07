# frozen_string_literal: true

# Dual H1-style switchers for teammate profile chrome: Teammate × Modality.
# Same interaction language as Object × Lens (`shared/object_lens_header/switchers`).
# Modality rows mirror `people/view_switcher` (icons, labels, policies, disabled tooltips).
# Relies on PeopleHelper / TerminologyHelper methods available in the view context.
module TeammateModalityHeaderHelper
  # Build path when switching teammates: prefer same modality when allowed, else /internal.
  def teammate_modality_path_for_teammate_switch(organization, teammate, preferred_path: nil, modality_key: nil)
    modality_key = (modality_key || people_current_modality_key).to_sym
    if preferred_path.present? && teammate_modality_allowed?(teammate, modality_key)
      return preferred_path
    end

    canonical = teammate_modality_canonical_path(organization, teammate, modality_key)
    if canonical.present? && teammate_modality_allowed?(teammate, modality_key)
      return canonical
    end

    if policy(teammate).internal?
      internal_organization_company_teammate_path(organization, teammate_route_param(teammate))
    else
      preferred_path.presence || organization_company_teammate_path(organization, teammate_route_param(teammate))
    end
  end

  def people_current_modality_key
    return :set_assignments if controller_name == "company_teammates" && action_name == "assignment_tenure_check_in_bypass"
    return :clarity_check_ins if clarity_check_ins_view_active?
    return :ogos if controller_name == "ogos" && %w[about from feedback_requests source_from_slack].include?(action_name)
    return :one_thing if controller_name == "one_on_one_links" && %w[show detailed overview work_to_meet].include?(action_name)
    return :seat_management if controller_name == "position" && action_name == "show"
    return :kudos if controller_name == "company_teammates" && action_name == "kudos_points"
    return :goals if controller_name == "company_teammates" && action_name == "my_growth_goals"
    if controller_name == "company_teammates" && %w[my_growth_experiences my_growth_abilities my_growth_position_change].include?(action_name)
      return :growth
    end
    if controller_path == "organizations/company_teammates/maap_teammate_growth" && action_name == "show"
      return :one_thing
    end

    case action_name.to_s.downcase
    when "teammate", "internal" then :teammate
    when "complete_picture" then :complete_picture
    when "true_jd_print" then :true_jd_print
    when "public" then :public
    when "about_me" then :about_me
    when "show"
      if controller_name.in?(%w[people company_teammates notifications])
        :profile_settings
      else
        :profile_settings
      end
    else
      :profile_settings
    end
  end

  def people_current_modality_icon
    teammate_modality_menu_items(@teammate).find { |item| item[:active] }&.dig(:icon) || "bi-eye"
  end

  # Closed header sits next to the teammate name — drop "{casual}'s " from modality labels.
  # Menu rows keep the full possessive label.
  def teammate_modality_closed_label(teammate, label = people_current_view_name)
    return label if teammate.blank? || label.blank?

    casual = teammate.person&.casual_name.to_s.presence
    return label if casual.blank?

    prefix = "#{casual}'s "
    label.start_with?(prefix) ? label.delete_prefix(prefix) : label
  end

  def can_set_assignments_for_teammate?(teammate)
    return false unless teammate && current_company_teammate

    # Match assignment_tenure_check_in_bypass authorization: manage_employment OR actual
    # managerial hierarchy. Do not use policy(teammate).manager? — that allows self.
    return true if policy(current_organization).manage_employment?

    current_company_teammate.in_managerial_hierarchy_of?(teammate)
  end

  def teammate_modality_menu_items(teammate)
    organization = current_organization
    return [] unless teammate && organization

    [
      teammate_modality_item(
        key: :teammate,
        icon: "bi-people",
        label: teammate_view_label_for(teammate),
        active: action_name.in?(%w[teammate internal]),
        path: (internal_organization_company_teammate_path(organization, teammate_route_param(teammate)) if policy(teammate).internal?),
        allowed: policy(teammate).internal?,
        disabled_tooltip: "You must be an active employee in the same organization to view the teammate version"
      ),
      teammate_modality_item(
        key: :complete_picture,
        icon: "bi-graph-up",
        label: active_job_label_for(teammate),
        active: action_name == "complete_picture",
        path: (complete_picture_organization_company_teammate_path(organization, teammate_route_param(teammate)) if policy(teammate).complete_picture?),
        allowed: policy(teammate).complete_picture?,
        disabled_tooltip: "You need employment management permissions or to be in the managerial hierarchy to access complete picture features"
      ),
      teammate_modality_item(
        key: :true_jd_print,
        icon: "bi-printer",
        label: true_jd_print_view_label_for(teammate),
        active: action_name == "true_jd_print",
        path: (true_jd_print_organization_company_teammate_path(organization, teammate_route_param(teammate)) if policy(teammate).true_jd_print?),
        allowed: policy(teammate).true_jd_print?,
        disabled_tooltip: "You must be an active employee in the same organization to view the print True Job Description (JD)"
      ),
      one_thing_modality_item(organization, teammate),
      teammate_modality_item(
        key: :growth,
        icon: "bi-flask",
        label: growth_label_for(teammate),
        active: controller_name == "company_teammates" && %w[my_growth_experiences my_growth_abilities my_growth_goals my_growth_position_change].include?(action_name),
        path: (my_growth_experiences_organization_company_teammate_path(organization, teammate_route_param(teammate)) if policy(teammate).complete_picture?),
        allowed: policy(teammate).complete_picture?,
        disabled_tooltip: "You need employment management permissions or to be in the managerial hierarchy to access complete picture features"
      ),
      public_modality_item(teammate),
      set_assignments_modality_item(organization, teammate),
      teammate_modality_item(
        key: :clarity_check_ins,
        icon: "bi-chat-square-text",
        label: clarity_check_ins_view_switcher_label,
        active: clarity_check_ins_view_active?,
        path: (hub_organization_company_teammate_check_ins_path(organization, teammate_route_param(teammate)) if policy(teammate).view_check_ins?),
        allowed: policy(teammate).view_check_ins?,
        disabled_tooltip: clarity_check_in_features_tooltip
      ),
      ogos_modality_item(organization, teammate),
      teammate_modality_item(
        key: :goals,
        icon: "bi-bullseye",
        label: goals_label_for(teammate),
        active: controller_name == "company_teammates" && action_name == "my_growth_goals",
        path: (my_growth_goals_organization_company_teammate_path(organization, teammate_route_param(teammate)) if policy(teammate).complete_picture?),
        allowed: policy(teammate).complete_picture?,
        disabled_tooltip: "You need employment management permissions or to be in the managerial hierarchy to view this teammate's goals."
      ),
      kudos_modality_item(organization, teammate),
      teammate_modality_item(
        key: :about_me,
        icon: "bi-person",
        label: about_me_classic_label,
        active: action_name == "about_me" && controller_name == "company_teammates",
        path: (about_me_organization_company_teammate_path(organization, teammate_route_param(teammate)) if policy(teammate).view_check_ins?),
        allowed: policy(teammate).view_check_ins?,
        disabled_tooltip: "You need employment management permissions or to be in the managerial hierarchy to access check-in features"
      ),
      teammate_modality_item(
        key: :seat_management,
        icon: "bi-briefcase",
        label: seat_management_label,
        active: action_name == "show" && controller_name == "position",
        path: (organization_teammate_position_path(organization, teammate_route_param(teammate)) if policy(teammate).show?),
        allowed: policy(teammate).show?,
        disabled_tooltip: "You need employment management permissions or to be in the managerial hierarchy to access seat management"
      ),
      teammate_modality_item(
        key: :profile_settings,
        icon: "bi-gear",
        label: profile_settings_label,
        active: action_name == "show" && controller_name.in?(%w[people company_teammates notifications]),
        path: (organization_company_teammate_path(organization, teammate_route_param(teammate)) if policy(teammate).show?),
        allowed: policy(teammate).show?,
        disabled_tooltip: "You need employment management permissions or to be in the managerial hierarchy to access management features"
      )
    ]
  end

  def teammate_modality_allowed?(teammate, modality_key)
    return false unless teammate

    case modality_key.to_sym
    when :teammate then policy(teammate).internal?
    when :complete_picture then policy(teammate).complete_picture?
    when :true_jd_print then policy(teammate).true_jd_print?
    when :one_thing
      policy(teammate.one_on_one_link || OneOnOneLink.new(teammate: teammate)).show?
    when :growth, :goals then policy(teammate).complete_picture?
    when :public then teammate.person.present?
    when :set_assignments
      can_set_assignments_for_teammate?(teammate)
    when :clarity_check_ins, :about_me then policy(teammate).view_check_ins?
    when :ogos
      policy(teammate.one_on_one_link || OneOnOneLink.new(teammate: teammate)).ogos?
    when :kudos
      current_company_teammate == teammate || policy(teammate).view_kudos_points?
    when :seat_management, :profile_settings then policy(teammate).show?
    else
      false
    end
  end

  def teammate_modality_canonical_path(organization, teammate, modality_key)
    return nil unless teammate && organization

    tm = teammate_route_param(teammate)
    case modality_key.to_sym
    when :teammate then internal_organization_company_teammate_path(organization, tm)
    when :complete_picture then complete_picture_organization_company_teammate_path(organization, tm)
    when :true_jd_print then true_jd_print_organization_company_teammate_path(organization, tm)
    when :one_thing then organization_company_teammate_one_on_one_link_path(organization, tm)
    when :growth then my_growth_experiences_organization_company_teammate_path(organization, tm)
    when :public then (public_person_path(teammate.person) if teammate.person)
    when :set_assignments then assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, tm)
    when :clarity_check_ins then hub_organization_company_teammate_check_ins_path(organization, tm)
    when :ogos then ogos_organization_company_teammate_path(organization, tm)
    when :goals then my_growth_goals_organization_company_teammate_path(organization, tm)
    when :kudos then kudos_points_organization_company_teammate_path(organization, tm)
    when :about_me then about_me_organization_company_teammate_path(organization, tm)
    when :seat_management then organization_teammate_position_path(organization, tm)
    when :profile_settings then organization_company_teammate_path(organization, tm)
    end
  end

  private

  def teammate_modality_item(key:, icon:, label:, active:, path:, allowed:, disabled_tooltip:)
    {
      key: key,
      icon: icon,
      label: label,
      active: active,
      path: path,
      allowed: allowed,
      disabled_tooltip: disabled_tooltip
    }
  end

  def one_thing_modality_item(organization, teammate)
    one_on_one_active = controller_name == "one_on_one_links" && %w[show detailed].include?(action_name)
    one_on_one_link = teammate.one_on_one_link || OneOnOneLink.new(teammate: teammate)
    allowed = policy(one_on_one_link).show?
    teammate_modality_item(
      key: :one_thing,
      icon: "bi-link-45deg",
      label: allowed ? one_thing_label_for(teammate) : one_on_one_hub_label,
      active: one_on_one_active,
      path: (organization_company_teammate_one_on_one_link_path(organization, teammate_route_param(teammate)) if allowed),
      allowed: allowed,
      disabled_tooltip: "You can open My One Thing for yourself, people in your managerial hierarchy, or if you have manage employment permission."
    )
  end

  def public_modality_item(teammate)
    allowed = teammate.person.present?
    teammate_modality_item(
      key: :public,
      icon: "bi-globe",
      label: allowed ? public_profile_label_for(teammate) : "Public Profile",
      active: action_name == "public",
      path: (public_person_path(teammate.person) if allowed),
      allowed: allowed,
      disabled_tooltip: nil
    )
  end

  def set_assignments_modality_item(organization, teammate)
    active = controller_name == "company_teammates" && action_name == "assignment_tenure_check_in_bypass"
    allowed = can_set_assignments_for_teammate?(teammate)
    teammate_modality_item(
      key: :set_assignments,
      icon: "bi-lightning-charge",
      label: set_assignments_view_label,
      active: active,
      path: (assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, teammate_route_param(teammate)) if allowed),
      allowed: allowed,
      disabled_tooltip: "You must be in this teammate's managerial hierarchy or have the manage employment permission."
    )
  end

  def ogos_modality_item(organization, teammate)
    active = controller_name == "ogos" && %w[about from feedback_requests].include?(action_name)
    label = ogos_label_for(teammate)
    allowed = policy(teammate.one_on_one_link || OneOnOneLink.new(teammate: teammate)).ogos?
    teammate_modality_item(
      key: :ogos,
      icon: "bi-chat-quote",
      label: label,
      active: active,
      path: (ogos_organization_company_teammate_path(organization, teammate_route_param(teammate)) if allowed),
      allowed: allowed,
      disabled_tooltip: "You can view OGOs for yourself, people in your managerial hierarchy, or if you have manage employment permission."
    )
  end

  def kudos_modality_item(organization, teammate)
    viewing_own = current_company_teammate == teammate
    allowed = viewing_own || policy(teammate).view_kudos_points?
    label = company_label_plural("kudos_point", "Kudos Point")
    teammate_modality_item(
      key: :kudos,
      icon: "bi-star",
      label: label,
      active: action_name == "kudos_points" && controller_name == "company_teammates",
      path: (kudos_points_organization_company_teammate_path(organization, teammate_route_param(teammate)) if allowed),
      allowed: allowed,
      disabled_tooltip: "You can only view your own #{company_label_plural('kudos_point', 'Kudos Point')} or those of people in your managerial hierarchy"
    )
  end
end
