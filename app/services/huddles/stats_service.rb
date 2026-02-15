module Huddles
  class StatsService
    def initialize(organization, date_range = nil)
      @organization = organization
      @date_range = date_range || default_date_range
    end

    # Core stats methods
    def feedback_stats
      @feedback_stats ||= calculate_feedback_stats
    end

    def participation_stats
      @participation_stats ||= calculate_participation_stats
    end

    def rating_stats
      @rating_stats ||= calculate_rating_stats
    end

    def weekly_stats
      @weekly_stats ||= calculate_weekly_stats
    end

    def overall_stats
      @overall_stats ||= calculate_overall_stats
    end

    def team_stats
      @team_stats ||= calculate_team_stats
    end

    # Public method for accessing huddles in range (used in tests)
    def huddles_in_range
    @huddles_in_range ||= Huddle.joins(team: :company)
                                 .where(teams: { company_id: organization.id })
                                 .where(started_at: date_range.begin.beginning_of_day..date_range.end.end_of_day)
                                 .includes(:huddle_feedbacks, :huddle_participants, team: [:company, :department, :team_members])
                                 .order(started_at: :desc)
    end

    # Public methods for testing (used in specs)
    def calculate_feedback_stats
      feedback_count = HuddleFeedback.joins(huddle: :team)
                                    .where(teams: { company_id: organization.id })
                                    .where(created_at: date_range.begin..date_range.end)
                                    .count

      unique_participants = HuddleFeedback.joins(huddle: :team)
                                         .where(teams: { company_id: organization.id })
                                         .where(created_at: date_range.begin..date_range.end)
                                         .distinct
                                         .count(:teammate_id)

      {
        feedback_count: feedback_count,
        unique_participants: unique_participants,
        start_date: date_range.begin,
        end_date: date_range.end
      }
    end

    def calculate_participation_stats
      total_participants = huddles_in_range.sum { |h| h.huddle_participants.count }
      total_feedbacks = huddles_in_range.sum { |h| h.huddle_feedbacks.count }

      # Calculate distinct participants
      distinct_participants = huddles_in_range.flat_map(&:huddle_participants).map(&:teammate).map(&:person).uniq(&:id)
      distinct_participant_count = distinct_participants.count
      distinct_participant_names = distinct_participants.map(&:display_name).sort

      participation_rate = total_participants > 0 ? (total_feedbacks.to_f / total_participants * 100).round(1) : 0

      {
        total_participants: total_participants,
        total_feedbacks: total_feedbacks,
        distinct_participant_count: distinct_participant_count,
        distinct_participant_names: distinct_participant_names,
        participation_rate: participation_rate
      }
    end

    def calculate_rating_stats
      all_ratings = huddles_in_range.flat_map(&:huddle_feedbacks).map(&:nat_20_score).compact
      average_rating = all_ratings.any? ? (all_ratings.sum.to_f / all_ratings.count).round(1) : 0

      # Calculate rating distribution
      rating_distribution = all_ratings.tally

      # Calculate conflict style distribution
      personal_conflict_styles = huddles_in_range.flat_map(&:huddle_feedbacks).map(&:personal_conflict_style).compact
      team_conflict_styles = huddles_in_range.flat_map(&:huddle_feedbacks).map(&:team_conflict_style).compact

      {
        average_rating: average_rating,
        rating_distribution: rating_distribution,
        personal_conflict_styles: personal_conflict_styles.tally,
        team_conflict_styles: team_conflict_styles.tally
      }
    end

    def calculate_weekly_stats
      huddles_by_week = huddles_in_range.group_by { |huddle| huddle.started_at.beginning_of_week }

      weekly_stats = {}
      huddles_by_week.each do |week_start, huddles|
        participation_stats = calculate_participation_stats_for_huddles(huddles)
        rating_stats = calculate_rating_stats_for_huddles(huddles)

        weekly_stats[week_start] = {
          total_huddles: huddles.count,
          **participation_stats,
          **rating_stats,
          huddles: huddles
        }
      end

      weekly_stats
    end

    def calculate_overall_stats
      participation_stats.merge(rating_stats).merge(
        total_huddles: huddles_in_range.count
      )
    end

    def calculate_team_stats
      team_stats = {}

      huddles_in_range.group_by(&:team).each do |team, team_huddles|
        next unless team # Skip huddles without teams

        participation_stats = calculate_participation_stats_for_huddles(team_huddles)
        rating_stats = calculate_rating_stats_for_huddles(team_huddles)
        weekly_trends = calculate_team_weekly_trends(team_huddles)

        member_count = team.team_members.count
        member_attendance_rate = if member_count.positive?
          (participation_stats[:distinct_participant_count].to_f / member_count * 100).round(1)
        else
          0
        end

        team_stats[team.id] = {
          id: team.id,
          display_name: team.display_name,
          company_id: team.company&.id,
          company_name: team.company&.display_name || 'Unknown Company',
          department_name: team.department&.display_name || nil,
          member_count: member_count,
          member_attendance_rate: member_attendance_rate,
          total_huddles: team_huddles.count,
          **participation_stats,
          **rating_stats,
          weekly_trends: weekly_trends,
          huddles: team_huddles
        }
      end

      team_stats
    end

    private

    attr_reader :organization, :date_range

    def default_date_range
      end_date = Date.current
      start_date = end_date - 6.weeks
      start_date..end_date
    end

    def calculate_participation_stats_for_huddles(huddles)
      total_participants = huddles.sum { |h| h.huddle_participants.count }
      total_feedbacks = huddles.sum { |h| h.huddle_feedbacks.count }

      distinct_participants = huddles.flat_map(&:huddle_participants).map(&:teammate).map(&:person).uniq(&:id)
      distinct_participant_count = distinct_participants.count
      distinct_participant_names = distinct_participants.map(&:display_name).sort

      participation_rate = total_participants > 0 ? (total_feedbacks.to_f / total_participants * 100).round(1) : 0

      {
        total_participants: total_participants,
        total_feedbacks: total_feedbacks,
        distinct_participant_count: distinct_participant_count,
        distinct_participant_names: distinct_participant_names,
        participation_rate: participation_rate
      }
    end

    def calculate_rating_stats_for_huddles(huddles)
      all_ratings = huddles.flat_map(&:huddle_feedbacks).map(&:nat_20_score).compact
      average_rating = all_ratings.any? ? (all_ratings.sum.to_f / all_ratings.count).round(1) : 0

      rating_distribution = all_ratings.tally

      personal_conflict_styles = huddles.flat_map(&:huddle_feedbacks).map(&:display_personal_conflict_style).compact
      team_conflict_styles = huddles.flat_map(&:huddle_feedbacks).map(&:display_team_conflict_style).compact

      {
        average_rating: average_rating,
        rating_distribution: rating_distribution,
        personal_conflict_styles: personal_conflict_styles.tally,
        team_conflict_styles: team_conflict_styles.tally
      }
    end

    def calculate_team_weekly_trends(team_huddles)
      huddles_by_week = team_huddles.group_by { |huddle| huddle.started_at.beginning_of_week }

      weekly_trends = {}
      huddles_by_week.each do |week_start, huddles|
        rating_stats = calculate_rating_stats_for_huddles(huddles)
        participation_stats = calculate_participation_stats_for_huddles(huddles)

        weekly_trends[week_start] = {
          average_rating: rating_stats[:average_rating],
          participation_rate: participation_stats[:participation_rate],
          total_huddles: huddles.count
        }
      end

      weekly_trends
    end
  end
end
