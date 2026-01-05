module ObservableMoments
  class CreateGoalCheckInMomentService
    def self.call(...) = new(...).call
    
    def initialize(goal_check_in:, created_by:)
      @goal_check_in = goal_check_in
      @created_by = created_by
    end
    
    def call
      # Only create moment if confidence changed by 20+ percentage points
      return Result.err("Confidence change too small") unless confidence_delta_significant?
      
      # Primary observer is the person who did the check-in
      primary_observer = @goal_check_in.confidence_reporter.teammates.find_by(
        organization: @goal_check_in.goal.company
      )
      return Result.err("Could not find reporter's teammate in company") unless primary_observer
      
      # Build metadata
      metadata = {
        goal_id: @goal_check_in.goal_id,
        goal_title: @goal_check_in.goal.title,
        confidence_percentage: @goal_check_in.confidence_percentage,
        previous_confidence_percentage: previous_confidence_percentage,
        confidence_delta: confidence_delta
      }
      
      ObservableMoments::BaseObservableMomentService.new(
        momentable: @goal_check_in,
        company: @goal_check_in.goal.company,
        created_by: @created_by,
        primary_potential_observer: primary_observer,
        moment_type: :goal_check_in,
        occurred_at: @goal_check_in.updated_at || Time.current,
        metadata: metadata
      ).call
    end
    
    private
    
    def confidence_delta_significant?
      delta = confidence_delta
      delta.present? && delta.abs >= 20
    end
    
    def confidence_delta
      return nil unless @goal_check_in.confidence_percentage.present?
      
      previous = previous_confidence_percentage
      return nil if previous.nil?
      
      @goal_check_in.confidence_percentage - previous
    end
    
    def previous_confidence_percentage
      @previous_confidence_percentage ||= begin
        previous_check_in = GoalCheckIn
          .where(goal: @goal_check_in.goal)
          .where.not(id: @goal_check_in.id)
          .order(check_in_week_start: :desc, updated_at: :desc)
          .first
        previous_check_in&.confidence_percentage
      end
    end
  end
end

