# frozen_string_literal: true

module Insights
  # Insights: Real OG Leaders — Shared (team / department / company) goals board.
  # Same three signals as personal goals, attributed to goal owners of type
  # Organization, Department, or Team — not individuals.
  class RealOgLeadersOrgGoalsBuilder
    QUALIFYING_ASSOCIABLE_TYPES = %w[Assignment Ability Aspiration].freeze
    ORG_OWNER_TYPES = %w[Organization Department Team].freeze
    OWNER_KIND_LABELS = {
      "Organization" => "Company",
      "Department" => "Department",
      "Team" => "Team"
    }.freeze

    Entry = Struct.new(
      :owner_type,
      :owner_id,
      :owner,
      :owner_kind_label,
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
      stats_by_owner_key = {}

      org_goals = load_org_goals
      return [] if org_goals.empty?

      owner_key_by_goal_id = org_goals.each_with_object({}) do |goal, h|
        h[goal.id] = [goal.owner_type, goal.owner_id]
      end

      add_confidence_checks(stats_by_owner_key, owner_key_by_goal_id)
      add_connections(stats_by_owner_key, owner_key_by_goal_id)
      add_completions(stats_by_owner_key, owner_key_by_goal_id)

      return [] if stats_by_owner_key.empty?

      owners = load_owners(stats_by_owner_key.keys)

      stats_by_owner_key.filter_map do |owner_key, stats|
        owner_type, owner_id = owner_key
        owner = owners[owner_key]
        next unless owner

        confidence = stats[:confidence_check_count]
        connection = stats[:connection_count]
        completion = stats[:completion_count]
        next if confidence.zero? && connection.zero? && completion.zero?

        has_confidence = confidence.positive?
        has_connection = connection.positive?
        has_completion = completion.positive?

        Entry.new(
          owner_type: owner_type,
          owner_id: owner_id,
          owner: owner,
          owner_kind_label: OWNER_KIND_LABELS.fetch(owner_type, owner_type),
          confidence_check_count: confidence,
          connection_count: connection,
          completion_count: completion,
          has_confidence_check: has_confidence,
          has_connection: has_connection,
          has_completion: has_completion,
          has_all_three: has_confidence && has_connection && has_completion,
          latest_confidence_check_at: stats[:latest_confidence_check_at],
          display_name: owner_display_name(owner)
        )
      end.sort_by { |entry| sort_key(entry) }
    end

    private

    def load_org_goals
      Goal
        .where(company_id: @company.id, deleted_at: nil, owner_type: ORG_OWNER_TYPES)
        .where.not(owner_id: nil)
        .to_a
    end

    def load_owners(owner_keys)
      by_type = owner_keys.group_by(&:first)
      owners = {}

      by_type.each do |owner_type, keys|
        ids = keys.map(&:last)
        records =
          case owner_type
          when "Organization" then Organization.where(id: ids)
          when "Department" then Department.where(id: ids)
          when "Team" then Team.where(id: ids)
          else
            []
          end
        records.each { |record| owners[[owner_type, record.id]] = record }
      end

      owners
    end

    def owner_display_name(owner)
      if owner.respond_to?(:display_name)
        owner.display_name
      else
        owner.try(:name).to_s
      end
    end

    def add_confidence_checks(stats_by_owner_key, owner_key_by_goal_id)
      scope = GoalCheckIn
        .where(goal_id: owner_key_by_goal_id.keys)
        .where.not(confidence_reporter_id: nil)
      scope = scope.where(created_at: @range) if @range

      scope.pluck(:goal_id, :created_at).each do |goal_id, created_at|
        owner_key = owner_key_by_goal_id[goal_id]
        next unless owner_key

        bucket = stats_for(stats_by_owner_key, owner_key)
        bucket[:confidence_check_count] += 1
        if bucket[:latest_confidence_check_at].nil? || created_at > bucket[:latest_confidence_check_at]
          bucket[:latest_confidence_check_at] = created_at
        end
      end
    end

    def add_connections(stats_by_owner_key, owner_key_by_goal_id)
      # Distinct org goals counted once even if multiple connection types apply.
      goal_ids_by_owner = Hash.new { |h, k| h[k] = Set.new }
      org_goal_ids = owner_key_by_goal_id.keys

      association_scope = GoalAssociation
        .where(goal_id: org_goal_ids, associable_type: QUALIFYING_ASSOCIABLE_TYPES)
      association_scope = association_scope.where(created_at: @range) if @range
      association_scope.pluck(:goal_id).each do |goal_id|
        owner_key = owner_key_by_goal_id[goal_id]
        goal_ids_by_owner[owner_key] << goal_id if owner_key
      end

      prompt_scope = PromptGoal.where(goal_id: org_goal_ids)
      prompt_scope = prompt_scope.where(created_at: @range) if @range
      prompt_scope.pluck(:goal_id).each do |goal_id|
        owner_key = owner_key_by_goal_id[goal_id]
        goal_ids_by_owner[owner_key] << goal_id if owner_key
      end

      personal_goal_ids = Goal
        .where(company_id: @company.id, deleted_at: nil, owner_type: "CompanyTeammate")
        .pluck(:id)

      # Link to a personal goal, or to another team/dept/company goal.
      link_pairs = []
      if personal_goal_ids.any?
        personal_links = GoalLink.where(
          "(parent_id IN (?) AND child_id IN (?)) OR (parent_id IN (?) AND child_id IN (?))",
          org_goal_ids, personal_goal_ids, personal_goal_ids, org_goal_ids
        )
        personal_links = personal_links.where(created_at: @range) if @range
        link_pairs.concat(personal_links.pluck(:parent_id, :child_id))
      end

      org_to_org = GoalLink.where(parent_id: org_goal_ids, child_id: org_goal_ids)
      org_to_org = org_to_org.where(created_at: @range) if @range
      link_pairs.concat(org_to_org.pluck(:parent_id, :child_id))

      link_pairs.each do |parent_id, child_id|
        [parent_id, child_id].each do |goal_id|
          owner_key = owner_key_by_goal_id[goal_id]
          goal_ids_by_owner[owner_key] << goal_id if owner_key
        end
      end

      goal_ids_by_owner.each do |owner_key, goal_ids|
        stats_for(stats_by_owner_key, owner_key)[:connection_count] += goal_ids.size
      end
    end

    def add_completions(stats_by_owner_key, owner_key_by_goal_id)
      scope = Goal
        .where(id: owner_key_by_goal_id.keys)
        .where.not(completed_at: nil)
      scope = scope.where(completed_at: @range) if @range

      scope.pluck(:id).each do |goal_id|
        owner_key = owner_key_by_goal_id[goal_id]
        next unless owner_key

        stats_for(stats_by_owner_key, owner_key)[:completion_count] += 1
      end
    end

    def stats_for(hash, owner_key)
      hash[owner_key] ||= {
        confidence_check_count: 0,
        connection_count: 0,
        completion_count: 0,
        latest_confidence_check_at: nil
      }
    end

    def sort_key(entry)
      [
        -entry.confidence_check_count,
        -entry.connection_count,
        -entry.completion_count,
        -(entry.latest_confidence_check_at&.to_i || 0),
        entry.display_name.to_s.downcase
      ]
    end
  end
end
