# frozen_string_literal: true

module Organizations::CompanyTeammatesHelper
  include TerminologyHelper
  # Primary navigation rows (manager-lite style) plus additional grouped entries from the view switcher.
  # Keep enabled? flags in sync with app/views/people/_view_switcher.html.haml; 1:1 uses OneOnOneLinkPolicy#show?.
  #
  # When +for_one_on_one_hub:+ is true, the first tile links to the internal teammate page instead of this 1:1 hub
  # (caller is already on the 1:1 hub).
  def internal_teammate_views_primary_groups(organization, teammate, row_data: nil, for_one_on_one_hub: false)
    context = internal_teammate_views_context(organization, teammate)
    casual_name = context[:casual_name]
    row_data ||= ManagersViewCardDataService::RowData.new
    check_in_actions_needed = row_data.check_in_actions_needed.to_i
    active_goals_count = row_data.active_goals_count.to_i
    draft_goals_count = row_data.draft_goals_count.to_i
    ogos_given_count = row_data.ogos_given_30d_count.to_i
    ogos_received_count = row_data.ogos_received_30d_count.to_i
    active_goals_path = organization_goals_path(organization, owner_id: "CompanyTeammate_#{teammate.id}", status: "active", view: "hierarchical-collapsible")
    draft_goals_path = organization_goals_path(organization, owner_id: "CompanyTeammate_#{teammate.id}", status: "draft", view: "hierarchical-collapsible")
    check_in_action_word = check_in_actions_needed == 1 ? "action" : "actions"

    first_entry =
      if for_one_on_one_hub
        internal_teammate_views_entry(
          title: "Teammate View",
          description: "Employment, assignments, observations, goals, and quick navigation for this teammate.",
          path: internal_organization_company_teammate_path(organization, teammate),
          enabled: policy(teammate).internal?,
          tooltip: context[:internal_teammate_tooltip]
        )
      else
        internal_teammate_views_entry(
          title: "#{casual_name}'s next most important thing",
          description: "The highest-priority focus for your next 1:1 with this teammate.",
          path: organization_company_teammate_one_on_one_link_path(organization, teammate),
          enabled: context[:can_one_on_one],
          tooltip: context[:one_on_one_tooltip]
        )
      end

    [
      {
        label: "1:1, about & growth",
        entries: [
          first_entry,
          internal_teammate_views_entry(
            title: "About #{casual_name}",
            description: "Stories, goals, reflections, and read-only About Me check-in sections.",
            path: about_me_organization_company_teammate_path(organization, teammate),
            enabled: policy(teammate).view_check_ins?,
            tooltip: context[:hierarchy_check_ins]
          ),
          internal_teammate_views_entry(
            title: "Explore #{casual_name}'s Growth",
            description: "Experiences, abilities, goals, and position-change planning for this teammate.",
            path: my_growth_experiences_organization_company_teammate_path(organization, teammate),
            enabled: policy(teammate).complete_picture?,
            tooltip: context[:hierarchy_complete_picture]
          )
        ]
      },
      {
        label: "Clarity check-ins",
        entries: [
          internal_teammate_views_entry(
            title: "Complete #{check_in_actions_needed} check-in clarity #{check_in_action_word}",
            description: "Check-ins waiting for clarity or finalization with this teammate.",
            path: up_next_organization_company_teammate_check_ins_path(organization, teammate),
            enabled: policy(teammate).view_check_ins?,
            tooltip: context[:hierarchy_check_ins]
          ),
          internal_teammate_views_entry(
            title: "View last check-in",
            description: "Review the most recent finalized position, assignment, and aspiration check-ins.",
            path: review_most_recent_organization_company_teammate_check_ins_path(organization, teammate),
            enabled: policy(teammate).view_check_ins?,
            tooltip: context[:hierarchy_check_ins]
          ),
          internal_teammate_views_entry(
            title: clarity_hub_label,
            description: clarity_hub_description,
            path: hub_organization_company_teammate_check_ins_path(organization, teammate),
            enabled: policy(teammate).view_check_ins?,
            tooltip: context[:hierarchy_check_ins]
          )
        ]
      },
      {
        label: "OGOs",
        entries: [
          internal_teammate_views_entry(
            title: "#{ogos_given_count} #{'OGO'.pluralize(ogos_given_count)} #{casual_name} has given",
            description: "Feedback and observations this teammate published in the last #{Observations::HealthRecency::RECENCY_DAYS} days.",
            path: ogos_from_organization_company_teammate_path(organization, teammate),
            enabled: context[:can_ogos],
            tooltip: context[:one_on_one_tooltip]
          ),
          internal_teammate_views_entry(
            title: "#{ogos_received_count} #{'OGO'.pluralize(ogos_received_count)} #{casual_name} has received",
            description: "Feedback and observations about this teammate in the last #{Observations::HealthRecency::RECENCY_DAYS} days.",
            path: ogos_organization_company_teammate_path(organization, teammate),
            enabled: context[:can_ogos],
            tooltip: context[:one_on_one_tooltip]
          ),
          internal_teammate_views_entry(
            title: "#{casual_name} OGO Overview",
            description: "OGO health, feedback about this teammate, and feedback requests.",
            path: ogos_organization_company_teammate_path(organization, teammate),
            enabled: context[:can_ogos],
            tooltip: context[:one_on_one_tooltip]
          )
        ]
      },
      {
        label: "Goals",
        entries: [
          internal_teammate_views_entry(
            title: "#{casual_name}'s #{active_goals_count} active #{'goal'.pluralize(active_goals_count)}",
            description: "Goals this teammate has started and is actively working toward.",
            path: active_goals_path,
            enabled: policy(teammate).complete_picture?,
            tooltip: context[:hierarchy_complete_picture]
          ),
          internal_teammate_views_entry(
            title: "#{casual_name}'s #{draft_goals_count} draft #{'goal'.pluralize(draft_goals_count)}",
            description: "Goals drafted but not yet started.",
            path: draft_goals_path,
            enabled: policy(teammate).complete_picture?,
            tooltip: context[:hierarchy_complete_picture]
          ),
          internal_teammate_views_entry(
            title: "Grow by Goals",
            description: "Goal-centric growth view with check-ins and progress.",
            path: my_growth_goals_organization_company_teammate_path(organization, teammate),
            enabled: policy(teammate).complete_picture?,
            tooltip: context[:hierarchy_complete_picture]
          )
        ]
      },
      {
        label: "Grow by",
        entries: [
          internal_teammate_views_entry(
            title: "Grow by experiences",
            description: "Compare day-to-day assignments against the position blueprint.",
            path: my_growth_experiences_organization_company_teammate_path(organization, teammate),
            enabled: policy(teammate).complete_picture?,
            tooltip: context[:hierarchy_complete_picture]
          ),
          internal_teammate_views_entry(
            title: "Grow by Abilities",
            description: "Compare earned ability milestones against current and target position blueprints.",
            path: my_growth_abilities_organization_company_teammate_path(organization, teammate),
            enabled: policy(teammate).complete_picture?,
            tooltip: context[:hierarchy_complete_picture]
          ),
          internal_teammate_views_entry(
            title: "Position / Title Change",
            description: "Clarify readiness for the current role and a selected target role.",
            path: my_growth_position_change_organization_company_teammate_path(organization, teammate),
            enabled: policy(teammate).complete_picture?,
            tooltip: context[:hierarchy_complete_picture]
          )
        ]
      }
    ]
  end

  def internal_teammate_views_navigation_groups(organization, teammate, row_data: nil, for_one_on_one_hub: false)
    internal_teammate_views_primary_groups(organization, teammate, row_data: row_data, for_one_on_one_hub: for_one_on_one_hub) +
      internal_teammate_views_additional_groups(organization, teammate)
  end

  def internal_teammate_views_more_expand_label(collapsed_groups, casual_name:)
    count = collapsed_groups.sum { |group| group[:entries].size }
    views_actions_phrase =
      if count == 1
        "view or action you can take"
      else
        "views and actions you can take"
      end
    taste = collapsed_groups.map { |group| group[:label] }.to_sentence(
      two_words_connector: ", ",
      last_word_connector: ", and "
    )

    "Show #{count} more #{views_actions_phrase} for #{casual_name}: #{taste}"
  end

  def internal_teammate_views_additional_groups(organization, teammate)
    context = internal_teammate_views_context(organization, teammate)
    person = teammate.person

    [
      {
        label: "Visibility & job context",
        entries: [
          internal_teammate_views_entry(
            title: "Public view",
            description: "What anyone can see: public milestones and world-visible observations.",
            path: public_person_path(person),
            enabled: true,
            tooltip: nil
          ),
          internal_teammate_views_entry(
            title: "True day-to-day",
            description: "Active job context: position, assignments, milestones, and check-in history.",
            path: complete_picture_organization_company_teammate_path(organization, teammate),
            enabled: policy(teammate).complete_picture?,
            tooltip: context[:hierarchy_complete_picture]
          ),
          internal_teammate_views_entry(
            title: set_assignments_view_label,
            description: "Set or update this teammate's day-to-day assignment tenures.",
            path: assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, teammate),
            enabled: context[:can_set_assignments],
            tooltip: "You must be in this teammate's managerial hierarchy or have the manage employment permission."
          )
        ]
      },
      {
        label: "Profile & administration",
        entries: [
          internal_teammate_views_entry(
            title: "Manage profile",
            description: "Identities, permissions, digest, visits, and profile maintenance.",
            path: organization_company_teammate_path(organization, teammate),
            enabled: policy(teammate).show?,
            tooltip: context[:hierarchy_manage]
          ),
          internal_teammate_views_entry(
            title: "Seat Management",
            description: "Position, seat, employment changes, and org placement for this role.",
            path: organization_teammate_position_path(organization, teammate),
            enabled: policy(teammate).show?,
            tooltip: context[:hierarchy_seat]
          ),
          internal_teammate_views_entry(
            title: "Kudos Points",
            description: "Recognition points and awards involving this teammate.",
            path: kudos_points_organization_company_teammate_path(organization, teammate),
            enabled: context[:can_view_kudos],
            tooltip: context[:kudos_tooltip]
          )
        ]
      }
    ]
  end

  # Backward-compatible flat list (all navigation groups).
  def internal_teammate_views_navigation_entries(organization, teammate, for_one_on_one_hub: false, row_data: nil)
    internal_teammate_views_navigation_groups(organization, teammate, row_data: row_data, for_one_on_one_hub: for_one_on_one_hub)
      .flat_map { |group| group[:entries] }
  end

  private

  def internal_teammate_views_entry(title:, description:, path:, enabled:, tooltip:)
    { title: title, description: description, path: path, enabled: enabled, tooltip: tooltip }
  end

  def internal_teammate_views_context(organization, teammate)
    person = teammate.person
    viewing_own_kudos = current_company_teammate == teammate
    can_view_kudos = viewing_own_kudos || policy(teammate).view_kudos_points?
    one_on_one_link = teammate.one_on_one_link || OneOnOneLink.new(teammate: teammate)

    {
      casual_name: person.casual_name,
      can_one_on_one: policy(one_on_one_link).show?,
      can_ogos: policy(one_on_one_link).ogos?,
      can_view_kudos: can_view_kudos,
      can_set_assignments: policy(teammate).manager? || policy(organization).manage_employment?,
      kudos_tooltip: "You can only view your own #{company_label_plural('kudos_point', 'Kudos Point')} or those of people in your managerial hierarchy",
      hierarchy_complete_picture: "You need employment management permissions or to be in the managerial hierarchy to access complete picture features",
      hierarchy_check_ins: "You need employment management permissions or to be in the managerial hierarchy to access check-in features",
      hierarchy_seat: "You need employment management permissions or to be in the managerial hierarchy to access seat management",
      hierarchy_manage: "You need employment management permissions or to be in the managerial hierarchy to access management features",
      one_on_one_tooltip: "You can open the 1:1 workspace for yourself, people in your managerial hierarchy, or if you have manage employment permission.",
      internal_teammate_tooltip: "You must be an active employee in the same organization to view the teammate version"
    }
  end

  public

  # Verb shown under earned milestone slots (levels 1–5) on complete_picture.
  def complete_picture_milestone_verb_for_level(level)
    {
      1 => "Demonstrated",
      2 => "Established",
      3 => "Advanced",
      4 => "Expert",
      5 => "Distinguished"
    }[level.to_i] || "Earned"
  end

  def complete_picture_resolved_milestone_description(ability, level)
    ability.milestone_description(level).presence || Ability.default_milestone_description(level)
  end

  # Popover for an earned milestone: certification details + markdown ability milestone description.
  def complete_picture_earned_milestone_popover_html(milestone, ability)
    parts = [ complete_picture_milestone_certification_details_html(milestone) ]
    md = complete_picture_milestone_markdown_block_html(ability, milestone.milestone_level)
    parts << md if md.present?

    tag.div(class: "small text-start") { safe_join(parts) }
  end

  # Popover for a not-yet-earned level: markdown description only.
  def complete_picture_unearned_milestone_popover_html(ability, level)
    block = complete_picture_milestone_markdown_block_html(ability, level)
    if block.present?
      tag.div(class: "small text-start") { block }
    else
      tag.div(class: "small text-muted text-start") { "No description for this milestone yet." }
    end
  end

  def complete_picture_milestone_certification_details_html(milestone)
    certifier = milestone.certifying_teammate&.person&.display_name.presence || "Unknown"
    attained = format_date_in_user_timezone(milestone.attained_at)
    notes = milestone.certification_note.to_s.strip

    note_block =
      if notes.present?
        tag.div(class: "mt-2") do
          safe_join([ tag.strong("Notes:"), tag.br, simple_format(notes) ])
        end
      else
        tag.div(class: "mt-2 text-muted") { "No notes recorded." }
      end

    tag.div do
      safe_join([
        tag.div { safe_join([ tag.strong("Awarded by: "), h(certifier) ]) },
        tag.div { safe_join([ tag.strong("When: "), h(attained) ]) },
        note_block
      ])
    end
  end

  def complete_picture_milestone_markdown_block_html(ability, level)
    text = complete_picture_resolved_milestone_description(ability, level)
    return if text.blank?

    tag.div(class: "mt-2 pt-2 border-top markdown-content small complete-picture-milestone-popover-md") do
      render_markdown(text)
    end
  end

  # Bulk milestone award wizard: match Complete Picture milestone slot popovers (earned vs unearned + markdown).
  def bulk_milestone_award_milestone_popover_html(ability, level, milestone_rec)
    if level.to_i.zero?
      return tag.div(class: "small text-muted text-start") do
        "Milestone 0 clears every attainment for this ability on this teammate."
      end
    end

    if milestone_rec.present?
      complete_picture_earned_milestone_popover_html(milestone_rec, ability)
    else
      complete_picture_unearned_milestone_popover_html(ability, level.to_i)
    end
  end

  # HTML for 1:1 Hub "The One Thing" tie-break popover (hover on alert).
  def one_thing_eisenhower_popover_content
    content_tag(:div, class: "small text-start") do
      content_tag(:strong, "Eisenhower-style ordering:") +
        content_tag(:ol, class: "mb-0 mt-2 ps-3") do
          safe_join(
            [
              content_tag(:li, "Important and urgent"),
              content_tag(:li, "Urgent and unimportant"),
              content_tag(:li, "Not urgent and important"),
              content_tag(:li, "Not urgent and not important")
            ]
          )
        end
    end
  end

  # HTML for 1:1 Hub "The One Thing" tie-break popover (hover on alert).
  def one_thing_tie_breaks_popover_content
    content_tag(:div, class: "small text-start") do
      content_tag(:ul, class: "mb-0 ps-3") do
        safe_join(
          [
            content_tag(:li, class: "mb-2") do
              ("If we see several check-ins tied at the same priority level " \
               "-- then we need to order them by ").html_safe +
                content_tag(:strong, "finalization date") +
                " first, then ".html_safe +
                content_tag(:strong, "alphabetically") +
                ".".html_safe
            end,
            content_tag(:li, class: "mb-0") do
              ("If we see the phrase ").html_safe +
                content_tag(:strong, "“this week”") +
                " for goal check-ins ".html_safe +
                ("-- then we need to use the same Monday–Sunday window as weekly goal check-ins (the week whose ").html_safe +
                content_tag(:strong, "check-in week start") +
                " is that Monday, per the app’s goal check-in week start logic).".html_safe
            end
          ]
        )
      end
    end
  end
end
