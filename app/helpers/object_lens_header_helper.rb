# frozen_string_literal: true

# Dual H1-style switchers: Object (noun) × Lens (Directory/List | Health | Insights).
# See docs/UX/object-lens-header-switchers-rollout-plan.md
module ObjectLensHeaderHelper
  OBJECTS = [
    { key: :overall, label: "Overall" },
    { key: :goals, label: "Goals" },
    { key: :observations, label: "Observations" },
    { key: :check_ins, label: "Check-ins" },
    { key: :abilities, label: "Abilities" },
    # Org/MAAP catalog — not person-scoped like the objects above.
    { key: :assignments, label: "Assignments", divider_before: true }
  ].freeze

  # Browse slot: Overall uses Directory; typed objects use List.
  BROWSE_LENS_BY_OBJECT = {
    overall: :directory,
    goals: :list,
    observations: :list,
    check_ins: :list,
    abilities: :list,
    assignments: :list
  }.freeze

  LENS_LABELS = {
    directory: "Directory",
    list: "List",
    health: "Health",
    insights: "Insights"
  }.freeze

  FALLBACK_LENS_ORDER = %i[insights list directory health].freeze

  def object_lens_object_label(object_key)
    OBJECTS.find { |o| o[:key] == object_key }&.fetch(:label) || object_key.to_s.humanize
  end

  def object_lens_lens_label(lens_key)
    LENS_LABELS.fetch(lens_key) { lens_key.to_s.humanize }
  end

  def object_lens_browse_lens_for(object_key)
    BROWSE_LENS_BY_OBJECT.fetch(object_key)
  end

  def object_lens_path(organization, object_key, lens_key)
    case [object_key.to_sym, lens_key.to_sym]
    when %i[overall directory]
      organization_sitemap_path(organization)
    when %i[overall health]
      organization_protect_flow_path(organization)
    when %i[overall insights]
      organization_insights_og_scorecard_path(organization)
    when %i[goals list]
      organization_goals_path(organization)
    when %i[goals health]
      organization_goals_health_path(organization)
    when %i[goals insights]
      organization_insights_goals_path(organization)
    when %i[observations list]
      organization_observations_path(organization)
    when %i[observations health]
      organization_observations_health_path(organization)
    when %i[observations insights]
      organization_insights_observations_path(organization)
    when %i[check_ins list]
      return nil unless current_company_teammate

      hub_organization_company_teammate_check_ins_path(organization, current_company_teammate)
    when %i[check_ins health]
      organization_check_ins_health_path(organization)
    when %i[check_ins insights]
      organization_insights_check_ins_progress_path(organization)
    when %i[abilities list]
      organization_abilities_path(organization)
    when %i[abilities health]
      organization_milestones_health_path(organization)
    when %i[abilities insights]
      organization_insights_abilities_path(organization)
    when %i[assignments list]
      organization_assignments_path(organization)
    when %i[assignments health]
      organization_assignments_health_path(organization)
    when %i[assignments insights]
      organization_insights_assignments_path(organization)
    else
      nil
    end
  end

  def object_lens_lens_allowed?(organization, object_key, lens_key)
    return false if object_lens_path(organization, object_key, lens_key).blank?

    case [object_key.to_sym, lens_key.to_sym]
    when %i[overall directory]
      policy(organization).show?
    when %i[overall health]
      policy(organization).protect_flow?
    when %i[overall insights]
      policy(organization).view_observations?
    when %i[goals list], %i[goals insights]
      policy(organization).view_goals?
    when %i[goals health]
      policy(organization).goals_health?
    when %i[observations list], %i[observations insights]
      policy(organization).view_observations?
    when %i[observations health]
      policy(organization).observations_health?
    when %i[check_ins list]
      current_company_teammate.present? && policy(current_company_teammate).view_check_ins?
    when %i[check_ins health]
      policy(organization).check_ins_health?
    when %i[check_ins insights]
      policy(organization).check_ins_health?
    when %i[abilities list], %i[abilities insights]
      policy(organization).view_abilities?
    when %i[abilities health]
      policy(organization).milestones_health?
    when %i[assignments list], %i[assignments insights], %i[assignments health]
      policy(organization).view_assignments?
    else
      false
    end
  end

  def object_lens_available_lenses(organization, object_key)
    lenses = []
    browse = object_lens_browse_lens_for(object_key)
    lenses << browse if object_lens_lens_allowed?(organization, object_key, browse)
    %i[health insights].each do |lens|
      lenses << lens if object_lens_lens_allowed?(organization, object_key, lens)
    end
    lenses
  end

  def object_lens_available_objects(organization)
    OBJECTS.select do |object|
      object_lens_available_lenses(organization, object[:key]).any?
    end
  end

  # Prefer the requested lens; Directory↔List count as the same browse slot across objects.
  def object_lens_resolve_lens(organization, object_key, preferred_lens)
    preferred = preferred_lens.to_sym
    preferred = object_lens_browse_lens_for(object_key) if preferred.in?(%i[directory list])

    return preferred if object_lens_lens_allowed?(organization, object_key, preferred)

    FALLBACK_LENS_ORDER.each do |lens|
      candidate = lens.in?(%i[directory list]) ? object_lens_browse_lens_for(object_key) : lens
      return candidate if object_lens_lens_allowed?(organization, object_key, candidate)
    end

    object_lens_available_lenses(organization, object_key).first
  end

  def object_lens_path_for_object_change(organization, current_object:, current_lens:, new_object:)
    lens = object_lens_resolve_lens(organization, new_object, current_lens)
    return nil unless lens

    object_lens_path(organization, new_object, lens)
  end

  def object_lens_path_for_lens_change(organization, current_object:, new_lens:)
    return nil unless object_lens_lens_allowed?(organization, current_object, new_lens)

    object_lens_path(organization, current_object, new_lens)
  end

  def object_lens_menu_objects(organization, current_object:, current_lens:)
    object_lens_available_objects(organization).map do |object|
      key = object[:key]
      {
        key: key,
        label: object[:label],
        current: key == current_object,
        divider_before: object[:divider_before] == true,
        path: object_lens_path_for_object_change(
          organization,
          current_object: current_object,
          current_lens: current_lens,
          new_object: key
        )
      }
    end
  end

  def object_lens_menu_lenses(organization, current_object:, current_lens:)
    object_lens_available_lenses(organization, current_object).map do |lens|
      {
        key: lens,
        label: object_lens_lens_label(lens),
        current: lens == current_lens,
        path: object_lens_path_for_lens_change(
          organization,
          current_object: current_object,
          new_lens: lens
        )
      }
    end
  end
end
