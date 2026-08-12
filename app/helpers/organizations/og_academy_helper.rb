# frozen_string_literal: true

module Organizations::OgAcademyHelper
  OG_MASTER_ABILITY_NAME = "OG Mastery"

  MILESTONE_TRUST_PHRASES = {
    1 => "with only a small amount of assistance",
    2 => "with no assistance, and as a trusted mentor to others",
    3 => "as an expert within this discipline",
    4 => "at an expert level while setting the tone for the entire company",
    5 => "as an industry-recognized expert whose work elevates the community"
  }.freeze

  MILESTONE_STATUS_VERBS = {
    1 => "Demonstrated",
    2 => "Advanced",
    3 => "Expert",
    4 => "Coach",
    5 => "Industry-Recognized"
  }.freeze

  def og_academy_home_options(organization, company_teammate, casual)
    org_name = organization.name.presence || "Company"
    options = [
      ["og_academy", "OG Academy", "bi-mortarboard", "Stay oriented here while you build habits."],
      ["start_here", "Start Here dashboard", "bi-house-door", "Fully configurable widgets for power users."],
      ["one_on_one_hub", "#{casual}'s One Thing", "bi-link-45deg", "Focused on you and your weekly rhythm."],
      (company_teammate.has_direct_reports? ? ["protect_flow", "Protect Flow / employees", "bi-people-fill", "Lead with employee health in view."] : nil),
      ["goals", "#{casual}'s goals", "bi-bullseye", "Jump into their goals and confidence checks."],
      ["about_me", "About #{casual}", "bi-person", "Full About Me health dashboard."],
      ["my_growth_experiences", "My Growth · Experiences", "bi-briefcase", "Assignment experiences and growth path."],
      ["my_growth_abilities", "My Growth · Abilities", "bi-award", "Ability milestones and mileage."],
      ["my_growth_goals", "My Growth · Goals", "bi-flag", "Goals owned for growth tracking."],
      ["kudos", "#{org_name} Kudos", "bi-gift", "Company kudos wall and public recognition."],
      ["company_goals", "#{org_name} Goals", "bi-diagram-3", "Company-wide goals hierarchy."],
      ["celebrate_milestones", "Celebrate Milestones", "bi-trophy", "Recently earned Ability milestones."]
    ]
    options.compact
  end

  def og_academy_milestone_heading(level)
    verb = MILESTONE_STATUS_VERBS[level.level] || "Milestone #{level.level}"
    "#{OG_MASTER_ABILITY_NAME} @ Milestone #{level.level} #{verb}"
  end

  def og_academy_milestone_trust_caption(level, casual_name, earned: false)
    phrase = MILESTONE_TRUST_PHRASES[level.level] || "with the right amount of support"
    practice = level.title.to_s
    ability = OG_MASTER_ABILITY_NAME
    prefix = "Milestone #{level.level} of #{ability} means I, OG, "
    suffix = "entrust #{casual_name} to execute #{ability} #{phrase}. At this Milestone, we have demonstrated #{practice}."

    if earned
      "#{prefix}#{suffix}"
    else
      observing = "AM OBSERVING #{casual_name} TO SEE THEM DEMONSTRATE #{ability} SO THAT I CAN..."
      safe_join(
        [
          prefix,
          content_tag(
            :span,
            observing,
            class: "badge rounded-pill text-bg-warning text-dark text-wrap align-middle"
          ),
          " ",
          suffix
        ]
      )
    end
  end

  def og_academy_milestone_examples_caption
    "Usually Milestone attainment is not a pure checklist… usually there are examples of what it means to have demonstrated that Milestone. However, in this example Milestone we are tracking what you've done in OG to automate the process and give you a feel for what it's like to earn Milestones while guiding you towards OG Mastery… which is the mastery of continuous clarity and unfading growth for you, your employees, and the team overall."
  end

  # Levels to render as accordion bodies: open only the earliest incomplete, visible level.
  def og_academy_level_open?(level, progress)
    current = progress.current_level
    return false unless current

    level.level == current.level
  end

  def og_academy_healthy_goals_count(goal_eh_records)
    GoalsHealthEngagementHealthSupport.items_for(goal_eh_records).count do |record|
      record.status.to_s == EngagementHealth::HEALTHY
    end
  end

  def og_academy_ogos_received_caption(count)
    days = Observations::HealthRecency::RECENCY_DAYS
    "#{count} #{'OGO'.pluralize(count)} received in the past #{days} days"
  end

  def og_academy_healthy_goals_caption(count)
    "#{count} active and healthy #{'goal'.pluralize(count)}"
  end

  def og_academy_criterion_completion_popover_html(criterion)
    return nil unless criterion.done

    when_text = if criterion.attained_at.present?
                  format_date_in_user_timezone(criterion.attained_at)
                else
                  "Date not recorded"
                end

    content_tag(:div, class: "small text-start") do
      safe_join([
        content_tag(:p, class: "mb-2") do
          safe_join([content_tag(:strong, "What: "), ERB::Util.html_escape(criterion.what.presence || criterion.label)])
        end,
        content_tag(:p, class: "mb-2") do
          safe_join([content_tag(:strong, "When: "), ERB::Util.html_escape(when_text)])
        end,
        content_tag(:p, class: "mb-0") do
          safe_join([content_tag(:strong, "Why it matters: "), ERB::Util.html_escape(criterion.why_important.to_s)])
        end
      ])
    end
  end

  # Where the teammate can act on an incomplete criterion.
  # Returns a path string, or nil when only a hover explanation is appropriate.
  def og_academy_criterion_path_for(criterion, organization:, company_teammate:)
    return nil if criterion.done

    case criterion.key.to_sym
    when :check_in_types, :check_in_depth
      up_next_organization_company_teammate_check_ins_path(organization, company_teammate)
    when :published_ogo, :observe_three, :four_ratings
      select_type_organization_observations_path(organization)
    when :added_goal, :linked_goals
      new_organization_goal_path(organization, owner_id: "CompanyTeammate_#{company_teammate.id}")
    when :confidence_checks
      my_growth_goals_organization_company_teammate_path(organization, company_teammate)
    when :notifications
      organization_company_teammate_notifications_path(organization, company_teammate)
    when :visited_my_growth, :real_milestone
      my_growth_abilities_organization_company_teammate_path(organization, company_teammate)
    when :visited_my_one_thing
      organization_company_teammate_one_on_one_link_path(organization, company_teammate)
    when :visited_teammates_index, :visited_teammate_internals
      organization_employees_path(organization, spotlight: "teammate_tenures")
    when :visited_insights_and_billing
      organization_insights_path(organization)
    when :maap_comment, :maap_edits
      organization_positions_path(organization)
    when :employment_stewardship
      organization_seats_path(organization)
    end
  end
end
