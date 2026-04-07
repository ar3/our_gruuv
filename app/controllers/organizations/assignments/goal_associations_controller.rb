# frozen_string_literal: true

class Organizations::Assignments::GoalAssociationsController < Organizations::AssociableGoalAssociationsBaseController
  private

  def load_associable!
    policy_scope(Assignment).find(params[:assignment_id])
  end
end
