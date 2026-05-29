# frozen_string_literal: true

module Organizations
  module OneOnOneLinksHelper
    def one_on_one_hub_work_to_meet_tab_badge(summary)
      variant = summary.tab_variant
      count = summary.tab_count
      css =
        case variant
        when :danger then "badge rounded-pill text-bg-danger ms-2"
        when :info then "badge rounded-pill text-bg-info ms-2"
        else "badge rounded-pill text-bg-success ms-2"
        end

      content_tag(:span, count, class: css, aria: { label: work_to_meet_tab_badge_aria_label(variant, count) })
    end

    def work_to_meet_return_url
      work_to_meet_organization_company_teammate_one_on_one_link_path(organization, teammate_route_param(@teammate))
    end

    def work_to_meet_add_goal_path(associable)
      case associable
      when Assignment
        choose_manage_goals_organization_assignment_path(
          organization,
          associable,
          return_url: work_to_meet_return_url,
          return_text: "Back to Work to Meet",
          for_company_teammate_id: @teammate.id
        )
      when Aspiration
        choose_manage_goals_organization_aspiration_path(
          organization,
          associable,
          return_url: work_to_meet_return_url,
          return_text: "Back to Work to Meet",
          for_company_teammate_id: @teammate.id
        )
      end
    end

    def work_to_meet_teammate_lens_path(associable)
      case associable
      when Assignment
        organization_teammate_assignment_path(organization, @teammate, associable)
      when Aspiration
        organization_teammate_aspiration_path(organization, @teammate, associable)
      end
    end

    def work_to_meet_draft_goals_path
      organization_goals_path(
        organization,
        owner_id: "CompanyTeammate_#{@teammate.id}",
        status: "draft",
        view: "hierarchical-collapsible",
        return_url: work_to_meet_return_url,
        return_text: "Back to Work to Meet"
      )
    end

    def work_to_meet_add_ogo_path(associable)
      new_quick_note_organization_observations_path(
        organization,
        observee_ids: [@teammate.id],
        rateable_type: associable.class.name,
        rateable_id: associable.id,
        return_url: work_to_meet_return_url,
        return_text: "Back to Work to Meet"
      )
    end

    def work_to_meet_filtered_ogos_path(associable)
      organization_observations_path(
        organization,
        observee_ids: [@teammate.id],
        rateable_type: associable.class.name,
        rateable_id: associable.id,
        return_url: work_to_meet_return_url,
        return_text: "Back to Work to Meet"
      )
    end

    def work_to_meet_ogo_count_caption_for(row, casual_name)
      object_name = row.associable.respond_to?(:title) ? row.associable.title : row.associable.name
      phrase =
        if row.ogo_count.zero?
          "No OGOs where #{casual_name} is observed and #{object_name} is rated"
        else
          "#{pluralize(row.ogo_count, 'OGO')} where #{casual_name} is observed and #{object_name} is rated"
        end

      link_to phrase, work_to_meet_filtered_ogos_path(row.associable), class: "text-muted text-decoration-none"
    end

    private

    def work_to_meet_tab_badge_aria_label(variant, count)
      case variant
      when :danger
        "#{count} working-to-meet #{'area'.pluralize(count)} missing an active goal"
      when :info
        "#{count} working-to-meet #{'area'.pluralize(count)}, all with active goals"
      else
        "No essential working-to-meet areas"
      end
    end
  end
end
