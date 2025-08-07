module Huddles
  class WeeklyStatsService < StatsService
    def initialize(company)
      # For weekly stats, we want the past week (Monday to Sunday)
      start_date = 1.week.ago.beginning_of_week(:monday)
      end_date = 1.week.ago.end_of_week(:sunday)
      
      super(company, start_date..end_date)
    end

    # Override to provide weekly-specific stats
    def weekly_feedback_stats
      stats = feedback_stats
      participation_stats = participation_stats()
      rating_stats = rating_stats()
      
      huddle_count = huddles_in_range.count
      
      # Calculate collaborative team conflict style percentage
      team_conflict_styles = huddles_in_range.flat_map(&:huddle_feedbacks).map(&:team_conflict_style).compact
      collaborative_percentage = team_conflict_styles.any? ? 
        (team_conflict_styles.count('Collaborative').to_f / team_conflict_styles.count * 100).round(1) : 0
      
      # Calculate positive and constructive feedback count
      # This would be feedback with written comments (private_facilitator or private_department_head)
      positive_constructive_count = huddles_in_range.flat_map(&:huddle_feedbacks).count do |feedback|
        feedback.private_facilitator.present? || feedback.private_department_head.present?
      end
      
      {
        feedback_count: stats[:feedback_count],
        unique_participants: stats[:unique_participants],
        huddle_count: huddle_count,
        start_date: stats[:start_date],
        end_date: stats[:end_date],
        # Additional metrics for the weekly notification
        distinct_participants: participation_stats[:distinct_participant_count],
        average_rating: rating_stats[:average_rating],
        participation_rate: participation_stats[:participation_rate],
        collaborative_percentage: collaborative_percentage,
        positive_constructive_count: positive_constructive_count
      }
    end
  end
end 