# frozen_string_literal: true

module Goals
  # Empty-state copy + CTA for the goals index when the current owner/special filter
  # yields no goals. Message depends on what the "for X" filter is.
  class EmptyFilterFallback
    Result = Struct.new(
      :kind,
      :message,
      :message_segments,
      :reach_out_people,
      :cta_label,
      :cta_path,
      :cta_disabled,
      :cta_disabled_reason,
      keyword_init: true
    )

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(
      organization:,
      viewer:,
      all_my_teams_filter: false,
      everyone_in_company_filter: false,
      created_by_me_filter: false,
      my_relevant_goals_filter: false,
      owner_type: nil,
      owner_id: nil,
      viewer_teams: nil,
      can_create_goals: false
    )
      @organization = organization
      @viewer = viewer
      @all_my_teams_filter = all_my_teams_filter
      @everyone_in_company_filter = everyone_in_company_filter
      @created_by_me_filter = created_by_me_filter
      @my_relevant_goals_filter = my_relevant_goals_filter
      @owner_type = owner_type
      @owner_id = owner_id
      @viewer_teams = viewer_teams
      @can_create_goals = can_create_goals
    end

    def call
      return person_result if person_owner?
      return all_my_teams_result if @all_my_teams_filter
      return teams_result(resolved_teams) if team_owner? || team_list_owner?

      generic_result
    end

    private

    def person_owner?
      @owner_type == 'CompanyTeammate' && @owner_id.present? && !special_filter?
    end

    def team_owner?
      @owner_type == 'Team' && @owner_id.present? && !special_filter?
    end

    def team_list_owner?
      false
    end

    def special_filter?
      @all_my_teams_filter || @everyone_in_company_filter || @created_by_me_filter || @my_relevant_goals_filter
    end

    def person_result
      subject = CompanyTeammate.includes(:person).find_by(id: @owner_id)
      name = casual_name_for(subject) || 'this teammate'
      name_link = linked_name(name, teammate_show_path(subject))
      can_create = @viewer.present? && subject.present? && @viewer.can_create_personal_goals_for?(subject)
      path = select_create_path(for_company_teammate_id: subject&.id)
      segments = [
        segment('Create a goal for '),
        name_link,
        segment('.')
      ]

      Result.new(
        kind: :person,
        message: plain_message(segments),
        message_segments: segments,
        reach_out_people: [],
        cta_label: "Create a goal for #{name}",
        cta_path: path,
        cta_disabled: !can_create || path.blank?,
        cta_disabled_reason: person_disabled_reason(name)
      )
    end

    def all_my_teams_result
      teams = Array(@viewer_teams)
      name = casual_name_for(@viewer) || 'you'
      name_link = linked_name(name, teammate_show_path(@viewer))

      if teams.empty?
        people = team_adders
        segments = [
          segment('What team(s) is '),
          name_link,
          segment(' on? Reach out to someone who can add people to teams.')
        ]
        Result.new(
          kind: :not_on_teams,
          message: plain_message(segments),
          message_segments: segments,
          reach_out_people: people,
          cta_label: nil,
          cta_path: nil,
          cta_disabled: true,
          cta_disabled_reason: nil
        )
      else
        teams_result(teams)
      end
    end

    def teams_result(teams)
      teams = Array(teams).compact
      name_links = teams.filter_map do |team|
        label = team.display_name.presence || team.name
        next if label.blank?

        linked_name(label, team_show_path(team))
      end
      create_owner_id = teams.size == 1 ? "Team_#{teams.first.id}" : nil
      path = if create_owner_id
               new_goal_path(owner_id: create_owner_id)
             else
               select_create_path(for_company_teammate_id: @viewer&.id)
             end
      verb = name_links.size == 1 ? 'has' : 'have'
      segments = names_sentence_segments(name_links) + [
        segment(" #{verb} no goals attached to them. Create one.")
      ]

      Result.new(
        kind: :teams_without_goals,
        message: plain_message(segments),
        message_segments: segments,
        reach_out_people: [],
        cta_label: 'Create a team goal',
        cta_path: path,
        cta_disabled: !@can_create_goals || path.blank?,
        cta_disabled_reason: @can_create_goals ? nil : 'You need to be a teammate to create goals'
      )
    end

    def generic_result
      owner_link = generic_owner_link
      label = owner_link[:text]
      path = generic_create_path
      segments = [
        segment('Create a goal for '),
        owner_link,
        segment('.')
      ]

      Result.new(
        kind: :generic,
        message: plain_message(segments),
        message_segments: segments,
        reach_out_people: [],
        cta_label: "Create a goal for #{label}",
        cta_path: path,
        cta_disabled: !@can_create_goals || path.blank?,
        cta_disabled_reason: @can_create_goals ? nil : 'You need to be a teammate to create goals'
      )
    end

    def generic_owner_link
      if @everyone_in_company_filter
        return segment('goals visible to everyone')
      end
      if @created_by_me_filter
        return segment('goals you created')
      end
      if @my_relevant_goals_filter
        return segment('your relevant goals')
      end

      case @owner_type
      when 'Organization', 'Company'
        org = Organization.find_by(id: @owner_id) || @organization
        linked_name(org&.display_name.presence || 'the company', organization_show_path(org))
      when 'Department'
        dept = Department.find_by(id: @owner_id)
        linked_name(
          dept&.display_name.presence || dept&.name || 'this department',
          department_show_path(dept)
        )
      else
        segment('this filter')
      end
    end

    def generic_create_path
      case @owner_type
      when 'Organization', 'Company'
        new_goal_path(owner_id: "Company_#{@owner_id || @organization.id}")
      when 'Department'
        new_goal_path(owner_id: "Department_#{@owner_id}") if @owner_id.present?
      else
        select_create_path(for_company_teammate_id: @viewer&.id)
      end
    end

    def resolved_teams
      return [] unless @owner_type == 'Team' && @owner_id.present?

      [Team.find_by(id: @owner_id)].compact
    end

    def team_adders
      company = @organization.root_company || @organization
      CompanyTeammate
        .where(organization: company)
        .with_departments_and_teams_management
        .includes(:person)
        .sort_by { |t| casual_name_for(t).to_s.downcase }
        .filter_map do |teammate|
          name = casual_name_for(teammate)
          next if name.blank?

          {
            name: name,
            path: teammate_show_path(teammate)
          }
        end
    end

    def select_create_path(for_company_teammate_id: nil)
      return nil unless @organization

      opts = {}
      opts[:for_company_teammate_id] = for_company_teammate_id if for_company_teammate_id.present?
      routes.select_create_organization_goals_path(@organization, opts)
    end

    def new_goal_path(owner_id:)
      return nil unless @organization && owner_id.present?

      routes.new_organization_goal_path(@organization, owner_id: owner_id)
    end

    def teammate_show_path(teammate)
      return nil unless @organization && teammate

      routes.internal_organization_company_teammate_path(@organization, teammate)
    end

    def team_show_path(team)
      return nil unless @organization && team

      routes.organization_team_path(@organization, team)
    end

    def department_show_path(department)
      return nil unless @organization && department

      routes.organization_department_path(@organization, department)
    end

    def organization_show_path(org)
      return nil unless org

      routes.organization_path(org)
    end

    def routes
      Rails.application.routes.url_helpers
    end

    def casual_name_for(teammate)
      return nil unless teammate&.person

      teammate.person.casual_name.presence || teammate.person.display_name
    end

    def person_disabled_reason(name)
      "You can't create goals for #{name}. You can create personal goals for yourself, people in your managerial hierarchy, or anyone if you manage employment for this company."
    end

    def segment(text)
      { text: text, path: nil }
    end

    def linked_name(text, path)
      { text: text, path: path }
    end

    def plain_message(segments)
      Array(segments).map { |part| part[:text].to_s }.join
    end

    def names_sentence_segments(name_links)
      links = Array(name_links)
      case links.size
      when 0
        [segment('These teams')]
      when 1
        [links.first]
      when 2
        [links[0], segment(' and '), links[1]]
      else
        parts = []
        links[0..-2].each_with_index do |link, index|
          parts << segment(', ') if index.positive?
          parts << link
        end
        parts << segment(', and ')
        parts << links[-1]
        parts
      end
    end
  end
end
