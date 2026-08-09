# frozen_string_literal: true

module Insights
  # Insights: Real OG Leaders — Goals board.
  # Three signals per teammate in a timeframe: confidence checks, "connected" goals
  # (prompt / assignment / ability / org-dept-team goal link — not personal-to-personal),
  # and completions. Star when all three are present.
  class RealOgLeadersGoalsBuilder
    QUALIFYING_ASSOCIABLE_TYPES = %w[Assignment Ability Aspiration].freeze
    ORG_OWNER_TYPES = %w[Organization Department Team].freeze

    Entry = Struct.new(
      :person,
      :company_teammate,
      :confidence_check_count,
      :connection_count,
      :completion_count,
      :has_confidence_check,
      :has_connection,
      :has_completion,
      :has_all_three,
      :latest_confidence_check_at,
      :display_name,
      keyword_init: true
    )

    def initialize(company:, range: nil)
      @company = company
      @range = range
    end

    def call
      stats_by_person_id = {}

      add_confidence_checks(stats_by_person_id)
      add_connections(stats_by_person_id)
      add_completions(stats_by_person_id)

      return [] if stats_by_person_id.empty?

      persons_by_id = Person.where(id: stats_by_person_id.keys).index_by(&:id)
      teammates_by_person_id = CompanyTeammate
        .where(organization: @company, person_id: stats_by_person_id.keys)
        .index_by(&:person_id)

      stats_by_person_id.filter_map do |person_id, stats|
        person = persons_by_id[person_id]
        next unless person

        confidence = stats[:confidence_check_count]
        connection = stats[:connection_count]
        completion = stats[:completion_count]
        next if confidence.zero? && connection.zero? && completion.zero?

        has_confidence = confidence.positive?
        has_connection = connection.positive?
        has_completion = completion.positive?

        Entry.new(
          person: person,
          company_teammate: teammates_by_person_id[person_id],
          confidence_check_count: confidence,
          connection_count: connection,
          completion_count: completion,
          has_confidence_check: has_confidence,
          has_connection: has_connection,
          has_completion: has_completion,
          has_all_three: has_confidence && has_connection && has_completion,
          latest_confidence_check_at: stats[:latest_confidence_check_at],
          display_name: person.display_name
        )
      end.sort_by { |entry| Insights::RealOgLeadersGoalsSort.sort_key(entry) }
    end

    private

    def add_confidence_checks(stats_by_person_id)
      scope = GoalCheckIn
        .joins(:goal)
        .where(goals: { company_id: @company.id, deleted_at: nil })
        .where.not(confidence_reporter_id: nil)

      scope = scope.where(created_at: @range) if @range

      scope.pluck(:confidence_reporter_id, :created_at).each do |person_id, created_at|
        bucket = stats_for(stats_by_person_id, person_id)
        bucket[:confidence_check_count] += 1
        if bucket[:latest_confidence_check_at].nil? || created_at > bucket[:latest_confidence_check_at]
          bucket[:latest_confidence_check_at] = created_at
        end
      end
    end

    def add_connections(stats_by_person_id)
      # Distinct personal goals counted once even if multiple connection types apply.
      goal_ids_by_person = Hash.new { |h, k| h[k] = Set.new }

      personal_goals = Goal
        .where(company_id: @company.id, owner_type: "CompanyTeammate", deleted_at: nil)
        .where.not(owner_id: nil)

      owner_person_by_goal_id = {}
      owner_person_by_teammate_id = CompanyTeammate
        .where(organization: @company)
        .pluck(:id, :person_id)
        .to_h

      personal_goals.pluck(:id, :owner_id).each do |goal_id, owner_id|
        person_id = owner_person_by_teammate_id[owner_id]
        next unless person_id

        owner_person_by_goal_id[goal_id] = person_id
      end

      return if owner_person_by_goal_id.empty?

      personal_goal_ids = owner_person_by_goal_id.keys

      association_scope = GoalAssociation
        .where(goal_id: personal_goal_ids, associable_type: QUALIFYING_ASSOCIABLE_TYPES)
      association_scope = association_scope.where(created_at: @range) if @range
      association_scope.pluck(:goal_id).each do |goal_id|
        person_id = owner_person_by_goal_id[goal_id]
        goal_ids_by_person[person_id] << goal_id if person_id
      end

      prompt_scope = PromptGoal.where(goal_id: personal_goal_ids)
      prompt_scope = prompt_scope.where(created_at: @range) if @range
      prompt_scope.pluck(:goal_id).each do |goal_id|
        person_id = owner_person_by_goal_id[goal_id]
        goal_ids_by_person[person_id] << goal_id if person_id
      end

      org_goal_ids = Goal
        .where(company_id: @company.id, deleted_at: nil, owner_type: ORG_OWNER_TYPES)
        .pluck(:id)
      if org_goal_ids.any?
        link_scope = GoalLink.where(
          "(parent_id IN (?) AND child_id IN (?)) OR (parent_id IN (?) AND child_id IN (?))",
          personal_goal_ids, org_goal_ids, org_goal_ids, personal_goal_ids
        )
        link_scope = link_scope.where(created_at: @range) if @range
        link_scope.pluck(:parent_id, :child_id).each do |parent_id, child_id|
          [parent_id, child_id].each do |goal_id|
            person_id = owner_person_by_goal_id[goal_id]
            goal_ids_by_person[person_id] << goal_id if person_id
          end
        end
      end

      goal_ids_by_person.each do |person_id, goal_ids|
        stats_for(stats_by_person_id, person_id)[:connection_count] += goal_ids.size
      end
    end

    def add_completions(stats_by_person_id)
      scope = Goal
        .where(company_id: @company.id, owner_type: "CompanyTeammate", deleted_at: nil)
        .where.not(completed_at: nil)
      scope = scope.where(completed_at: @range) if @range

      teammate_ids = scope.distinct.pluck(:owner_id)
      person_by_teammate = CompanyTeammate
        .where(id: teammate_ids, organization: @company)
        .pluck(:id, :person_id)
        .to_h

      scope.pluck(:owner_id).each do |owner_id|
        person_id = person_by_teammate[owner_id]
        next unless person_id

        stats_for(stats_by_person_id, person_id)[:completion_count] += 1
      end
    end

    def stats_for(hash, person_id)
      hash[person_id] ||= {
        confidence_check_count: 0,
        connection_count: 0,
        completion_count: 0,
        latest_confidence_check_at: nil
      }
    end
  end
end
