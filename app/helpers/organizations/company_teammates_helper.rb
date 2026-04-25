# frozen_string_literal: true

module Organizations::CompanyTeammatesHelper
  # Each entry: title, description, path, enabled, tooltip (for disabled; shown on wrapper with data-bs-toggle="tooltip").
  # Keep enabled? flags in sync with app/views/people/_view_switcher.html.haml; 1:1 uses OneOnOneLinkPolicy#show?.
  #
  # When +for_one_on_one_hub:+ is true, the first tile links to the internal teammate page instead of this 1:1 hub
  # (caller is already on the 1:1 hub).
  def internal_teammate_views_navigation_entries(organization, teammate, for_one_on_one_hub: false)
    tm = teammate
    person = tm.person
    viewing_own_kudos = current_company_teammate == tm
    can_view_kudos = viewing_own_kudos || policy(tm).view_kudos_points?

    one_on_one_link = tm.one_on_one_link || OneOnOneLink.new(teammate: tm)
    can_one_on_one = policy(one_on_one_link).show?

    kudos_tooltip = "You can only view your own #{company_label_plural('kudos_point', 'Kudos Point')} or those of people in your managerial hierarchy"
    hierarchy_complete_picture = "You need employment management permissions or to be in the managerial hierarchy to access complete picture features"
    hierarchy_check_ins = "You need employment management permissions or to be in the managerial hierarchy to access check-in features"
    hierarchy_seat = "You need employment management permissions or to be in the managerial hierarchy to access seat management"
    hierarchy_manage = "You need employment management permissions or to be in the managerial hierarchy to access management features"
    one_on_one_tooltip = "You can open the 1:1 workspace for yourself, people in your managerial hierarchy, or if you have manage employment permission."
    internal_teammate_tooltip = "You must be an active employee in the same organization to view the teammate version"

    first_entry =
      if for_one_on_one_hub
        {
          title: "Teammate View",
          description: "Employment, assignments, observations, goals, and quick navigation for this teammate.",
          path: internal_organization_company_teammate_path(organization, tm),
          enabled: policy(tm).internal?,
          tooltip: internal_teammate_tooltip
        }
      else
        {
          title: "1:1 Area",
          description: "Agendas, shared notes, and linked project tools for meetings with this teammate.",
          path: organization_company_teammate_one_on_one_link_path(organization, tm),
          enabled: can_one_on_one,
          tooltip: one_on_one_tooltip
        }
      end

    [
      first_entry,
      {
        title: "Public view",
        description: "What anyone can see: public milestones and world-visible observations.",
        path: public_person_path(person),
        enabled: true,
        tooltip: nil
      },
      {
        title: "True day-to-day",
        description: "Active job context: position, assignments, milestones, and check-in history.",
        path: complete_picture_organization_company_teammate_path(organization, tm),
        enabled: policy(tm).complete_picture?,
        tooltip: hierarchy_complete_picture
      },
      {
        title: "About Me",
        description: "Stories, goals, reflections, and read-only About Me check-in sections.",
        path: about_me_organization_company_teammate_path(organization, tm),
        enabled: policy(tm).view_check_ins?,
        tooltip: hierarchy_check_ins
      },
      {
        title: "My Growth",
        description: "Experiences, abilities, goals, and position-change planning for this teammate.",
        path: my_growth_experiences_organization_company_teammate_path(organization, tm),
        enabled: policy(tm).complete_picture?,
        tooltip: hierarchy_complete_picture
      },
      {
        title: "My Check-ins",
        description: "Check-in hub, spreadsheets, reviews, and finalization for this teammate.",
        path: hub_organization_company_teammate_check_ins_path(organization, tm),
        enabled: policy(tm).view_check_ins?,
        tooltip: hierarchy_check_ins
      },
      {
        title: "Kudos Points",
        description: "Recognition points and awards involving this teammate.",
        path: kudos_points_organization_company_teammate_path(organization, tm),
        enabled: can_view_kudos,
        tooltip: kudos_tooltip
      },
      {
        title: "Seat Management",
        description: "Position, seat, employment changes, and org placement for this role.",
        path: organization_teammate_position_path(organization, tm),
        enabled: policy(tm).show?,
        tooltip: hierarchy_seat
      },
      {
        title: "Manage profile",
        description: "Identities, permissions, digest, visits, and profile maintenance.",
        path: organization_company_teammate_path(organization, tm),
        enabled: policy(tm).show?,
        tooltip: hierarchy_manage
      }
    ]
  end

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
