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

    def playbook_stats
      @playbook_stats ||= calculate_playbook_stats
    end

    private

    attr_reader :organization, :date_range

    def default_date_range
      end_date = Date.current
      start_date = end_date - 6.weeks
      start_date..end_date
    end

    def huddles_in_range
      @huddles_in_range ||= Huddle.joins(:organization)
                                   .where(organization: organization.self_and_descendants)
                                   .where(started_at: date_range.begin.beginning_of_day..date_range.end.end_of_day)
                                   .includes(:organization, :huddle_playbook, :huddle_feedbacks, :huddle_participants)
                                   .order(:started_at)
    end

    def calculate_feedback_stats
      feedback_count = HuddleFeedback.joins(:huddle)
                                    .where(huddles: { organization: organization.self_and_descendants })
                                    .where(created_at: date_range.begin..date_range.end)
                                    .count

      unique_participants = HuddleFeedback.joins(:huddle)
                                         .where(huddles: { organization: organization.self_and_descendants })
                                         .where(created_at: date_range.begin..date_range.end)
                                         .distinct
                                         .count(:person_id)

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
      distinct_participants = huddles_in_range.flat_map(&:huddle_participants).map(&:person).uniq(&:id)
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

    def calculate_playbook_stats
      playbook_stats = {}
      
      huddles_in_range.group_by(&:huddle_playbook).each do |playbook, playbook_huddles|
        next unless playbook # Skip huddles without playbooks
        
        participation_stats = calculate_participation_stats_for_huddles(playbook_huddles)
        rating_stats = calculate_rating_stats_for_huddles(playbook_huddles)
        weekly_trends = calculate_playbook_weekly_trends(playbook_huddles)
        
        playbook_stats[playbook.id] = {
          id: playbook.id,
          display_name: playbook.display_name,
          organization_id: playbook.organization_id,
          organization_name: playbook.organization.display_name,
          total_huddles: playbook_huddles.count,
          **participation_stats,
          **rating_stats,
          weekly_trends: weekly_trends,
          huddles: playbook_huddles
        }
      end
      
      playbook_stats
    end

    def calculate_participation_stats_for_huddles(huddles)
      total_participants = huddles.sum { |h| h.huddle_participants.count }
      total_feedbacks = huddles.sum { |h| h.huddle_feedbacks.count }
      
      distinct_participants = huddles.flat_map(&:huddle_participants).map(&:person).uniq(&:id)
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

    def calculate_playbook_weekly_trends(playbook_huddles)
      huddles_by_week = playbook_huddles.group_by { |huddle| huddle.started_at.beginning_of_week }
      
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