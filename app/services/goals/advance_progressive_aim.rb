# frozen_string_literal: true

module Goals
  # Completes the current Progressive Outcome aim (if needed) and creates a new
  # linked goal aimed at the next band, with prose adjusted to drop the hit band.
  class AdvanceProgressiveAim
    Result = Struct.new(:ok?, :completed_goal, :next_goal, :error, keyword_init: true)

    AIM_ORDER = ProgressiveOutcomeProse::AIM_ORDER

    def self.call(...) = new(...).call

    def initialize(goal:, current_person:, current_teammate:)
      @goal = goal
      @current_person = current_person
      @current_teammate = current_teammate
    end

    def call
      return failure("Goal is not a Progressive Outcome") unless @goal.progressive_outcome?
      return failure("Goal is deleted") if @goal.deleted_at.present?

      hit_aim = @goal.progressive_current_aim.presence || "commit"
      next_aim = next_aim_after(hit_aim)
      return failure("No next aim after #{hit_aim}") if next_aim.nil?
      return failure("Next aim value is missing") if outcome_value_for(next_aim).nil?

      PaperTrail.request.whodunnit = @current_teammate&.id&.to_s
      next_goal = nil

      ActiveRecord::Base.transaction do
        unless @goal.completed_at.present?
          @goal.update!(completed_at: Time.current, started_at: @goal.started_at || Time.current)
        end

        new_title = ProgressiveOutcomeProse.rewrite_after_hit(@goal.title, hit_aim: hit_aim)
        next_goal = build_next_goal(new_title: new_title, next_aim: next_aim, hit_aim: hit_aim)
        raise ActiveRecord::Rollback unless next_goal.persisted?

        link = GoalLink.new(parent_id: @goal.id, child_id: next_goal.id, metadata: {
          "progressive_advance" => true,
          "from_aim" => hit_aim,
          "to_aim" => next_aim
        })
        unless link.save
          next_goal.destroy
          raise ActiveRecord::Rollback
        end
      end

      return failure("Could not create next aim goal") if next_goal.nil? || !next_goal.persisted?

      EngagementHealth.schedule_refresh_for_goal(@goal)
      EngagementHealth.schedule_refresh_for_goal(next_goal)
      Result.new(ok?: true, completed_goal: @goal.reload, next_goal: next_goal, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.presence || e.message)
    end

    private

    def build_next_goal(new_title:, next_aim:, hit_aim:)
      company = @goal.company
      goal = Goal.new(company: company)
      form = GoalForm.new(goal)
      form.current_person = @current_person
      form.current_teammate = @current_teammate

      owner_type = @goal.owner_type == "Organization" ? "Company" : @goal.owner_type
      owner_value = "#{owner_type}_#{@goal.owner_id}"

      payload = {
        title: new_title,
        description: @goal.description.to_s,
        goal_type: "progressive_outcome",
        owner_id: owner_value,
        privacy_level: @goal.privacy_level,
        edit_check_in_permission: @goal.edit_check_in_permission,
        most_likely_target_date: @goal.most_likely_target_date,
        earliest_target_date: @goal.earliest_target_date,
        latest_target_date: @goal.latest_target_date,
        initial_confidence: @goal.initial_confidence,
        outcome_baseline: @goal.outcome_baseline,
        outcome_commit: @goal.outcome_commit,
        outcome_stretch: @goal.outcome_stretch,
        outcome_transform: @goal.outcome_transform,
        outcome_unit: @goal.outcome_unit,
        progressive_current_aim: next_aim
      }

      # Clear the hit band value so the new aim is clear; keep higher bands.
      case hit_aim
      when "commit"
        # keep commit value for history in fields; current aim moves on
      when "stretch"
        # no-op
      end

      unless form.validate(payload) && form.save
        goal.errors.copy!(form.errors) if goal.errors.empty?
        return goal
      end

      goal.update!(
        progressive_current_aim: next_aim,
        outcome_baseline: @goal.outcome_baseline,
        outcome_commit: @goal.outcome_commit,
        outcome_stretch: @goal.outcome_stretch,
        outcome_transform: @goal.outcome_transform,
        outcome_unit: @goal.outcome_unit,
        started_at: Time.current
      )
      goal
    end

    def next_aim_after(aim)
      idx = AIM_ORDER.index(aim.to_s)
      return nil if idx.nil?

      AIM_ORDER[(idx + 1)..].find { |candidate| outcome_value_for(candidate).present? }
    end

    def outcome_value_for(aim)
      case aim.to_s
      when "commit" then @goal.outcome_commit
      when "stretch" then @goal.outcome_stretch
      when "transform" then @goal.outcome_transform
      end
    end

    def failure(message)
      Result.new(ok?: false, completed_goal: @goal, next_goal: nil, error: message)
    end
  end
end
