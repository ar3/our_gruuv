# frozen_string_literal: true

module HealthNudges
  # Builds compact JSON context for Protect Flow nudge Consult OG (~45 days).
  class ProtectFlowNudgeContextBuilder
    LOOKBACK_DAYS = 45

    # Mirrors OneOnOne::PriorityCarouselBuilder#build_priorities order (lower = higher leverage).
    # health_signals: Protect Flow categories this One Thing item usually informs.
    ONE_THING_PRIORITY_ORDER = [
      { position: 1, key: "asana_urgent_tasks", health_signals: [] },
      { position: 2, key: "check_ins_ready_for_review", health_signals: [EngagementHealth::CATEGORY_REQUIRED_CLARITY] },
      { position: 3, key: "required_clarity_attention", health_signals: [EngagementHealth::CATEGORY_REQUIRED_CLARITY] },
      { position: 4, key: "wtm_required_or_active_without_goals", health_signals: [EngagementHealth::CATEGORY_GOAL_CONFIDENCE] },
      { position: 5, key: "current_position_milestone_gaps_without_goals", health_signals: [EngagementHealth::CATEGORY_MILESTONES] },
      { position: 6, key: "no_observation_given_30d", health_signals: [EngagementHealth::CATEGORY_OGO_GIVEN] },
      { position: 7, key: "no_observation_received_30d", health_signals: [EngagementHealth::CATEGORY_OGO_RECEIVED] },
      { position: 8, key: "no_wtm_observation_received_30d", health_signals: [EngagementHealth::CATEGORY_OGO_RECEIVED] },
      { position: 9, key: "active_goals_without_check_in_this_week", health_signals: [EngagementHealth::CATEGORY_GOAL_CONFIDENCE] },
      { position: 10, key: "no_active_goals", health_signals: [EngagementHealth::CATEGORY_GOAL_CONFIDENCE] },
      { position: 11, key: "target_unique_milestone_gaps_without_goals", health_signals: [EngagementHealth::CATEGORY_MILESTONES] },
      { position: 12, key: "remaining_asana_tasks", health_signals: [] },
      { position: 13, key: "target_unique_required_assignments_without_goals", health_signals: [EngagementHealth::CATEGORY_REQUIRED_CLARITY, EngagementHealth::CATEGORY_GOAL_CONFIDENCE] }
    ].freeze

    def self.call(organization:, people:, viewer: nil)
      new(organization: organization, people: people, viewer: viewer).call
    end

    def initialize(organization:, people:, viewer: nil)
      @organization = organization
      @people = Array(people)
      @viewer = viewer
      @since = LOOKBACK_DAYS.days.ago
    end

    def call
      {
        lookback_days: LOOKBACK_DAYS,
        one_thing_priority_order: ONE_THING_PRIORITY_ORDER,
        one_thing_priority_guidance: "Recommend using earlier One Thing positions first when they need attention.",
        people: @people.map { |person| person_payload(person) }
      }
    end

    private

    def person_payload(person)
      teammate = person[:teammate]
      {
        name: person[:name],
        teammate_id: person[:teammate_id],
        worst_status: person[:worst_status],
        steady_count: person[:steady_count],
        week_needs_work_count: person[:week_needs_work_count],
        signals: Array(person[:statuses]).map { |s|
          {
            category: s[:category],
            status: s[:status],
            start_status: s[:start_status],
            improved: s[:improved]
          }
        },
        attention: Array(person[:attention_items]).map { |a|
          { category: a[:category], status: a[:status], short_title: a[:short_title] }
        },
        one_thing_needing_attention: one_thing_attention_for(teammate),
        ogos: ogo_context(teammate),
        goals: goal_context(teammate),
        milestones: milestone_context(teammate)
      }
    end

    def one_thing_attention_for(teammate)
      link = teammate.one_on_one_link || OneOnOneLink.new(teammate: teammate)
      carousel = OneOnOne::PriorityCarouselBuilder.call(
        organization: @organization,
        teammate: teammate,
        one_on_one_link: link,
        viewing_company_teammate: @viewer
      )
      Array(carousel[:priorities]).filter_map do |row|
        next unless row[:needs_attention] && !row[:not_applicable]

        {
          position: row[:position],
          title: row[:title].to_s.truncate(160),
          reason: row[:reason].to_s.truncate(220),
          cta_label: row[:cta_label]
        }
      end.first(5)
    rescue StandardError
      []
    end

    def ogo_context(teammate)
      person = teammate.person
      return {} unless person

      given = Observation.published.not_soft_deleted
        .where(company: company, observer: person)
        .where("observed_at >= ?", @since)
        .includes(:observation_ratings, observees: { company_teammate: :person })
        .order(observed_at: :desc)
        .limit(40)

      received = Observation.published.not_soft_deleted
        .joins(:observees)
        .where(company: company, observees: { teammate_id: teammate.id })
        .where("observations.observed_at >= ?", @since)
        .includes(:observer, :observation_ratings)
        .order("observations.observed_at DESC")
        .limit(40)

      {
        given_count: given.size,
        received_count: received.size,
        last_given: summarize_ogo(given.first, direction: :given),
        last_received: summarize_ogo(received.first, direction: :received),
        given_to_concentration: concentration_from_given(given),
        received_from_concentration: concentration_from_received(received),
        given_object_concentration: object_concentration(given),
        received_object_concentration: object_concentration(received)
      }
    end

    def summarize_ogo(observation, direction:)
      return nil unless observation

      {
        observed_at: observation.observed_at&.iso8601,
        type: observation.observation_type,
        story_excerpt: observation.story.to_s.truncate(160),
        counterpart: if direction == :given
                       observation.observees.filter_map { |o| o.company_teammate&.person&.casual_name }.first(3)
                     else
                       observation.observer&.casual_name
                     end,
        rateables: observation.observation_ratings.filter_map { |r|
          next unless r.rateable

          "#{r.rateable_type}: #{r.rateable.try(:name) || r.rateable.try(:title) || r.rateable_id}"
        }.first(5)
      }
    end

    def concentration_from_given(observations)
      counts = Hash.new(0)
      observations.each do |ogo|
        ogo.observees.each do |obs|
          name = obs.company_teammate&.person&.casual_name || "unknown"
          counts[name] += 1
        end
      end
      top_counts(counts)
    end

    def concentration_from_received(observations)
      counts = Hash.new(0)
      observations.each do |ogo|
        name = ogo.observer&.casual_name || "unknown"
        counts[name] += 1
      end
      top_counts(counts)
    end

    def object_concentration(observations)
      counts = Hash.new(0)
      observations.each do |ogo|
        ogo.observation_ratings.each do |rating|
          next unless rating.rateable

          label = "#{rating.rateable_type}: #{rating.rateable.try(:name) || rating.rateable.try(:title) || rating.rateable_id}"
          counts[label] += 1
        end
      end
      top_counts(counts)
    end

    def top_counts(counts)
      counts.sort_by { |_k, v| -v }.first(5).map { |k, v| { name: k, count: v } }
    end

    def goal_context(teammate)
      goals = Goal.where(company: company)
        .where(
          "(owner_type = ? AND owner_id = ?) OR (owner_type = ? AND owner_id = ?) OR creator_id = ?",
          "CompanyTeammate", teammate.id,
          "Person", teammate.person_id,
          teammate.id
        )
      check_ins = GoalCheckIn.where(goal_id: goals.select(:id))
        .where("created_at >= ?", @since)
        .includes(:goal)
        .order(created_at: :desc)
      last = check_ins.first
      {
        active_goal_count: goals.where(completed_at: nil).count,
        last_confidence_check: last && {
          at: last.created_at&.iso8601,
          confidence_percentage: last.confidence_percentage,
          goal: last.goal&.title
        }
      }
    rescue StandardError
      { active_goal_count: 0, last_confidence_check: nil }
    end

    def milestone_context(teammate)
      award = MilestoneAward.where(teammate_id: teammate.id)
        .where("created_at >= ?", @since)
        .includes(:ability)
        .order(created_at: :desc)
        .first
      {
        last_milestone_earned: award && {
          at: award.created_at&.iso8601,
          ability: award.ability&.name,
          level: award.official_milestone_level
        }
      }
    rescue StandardError
      { last_milestone_earned: nil }
    end

    def company
      @company ||= @organization.root_company || @organization
    end
  end
end
