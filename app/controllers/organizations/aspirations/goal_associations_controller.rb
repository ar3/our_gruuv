# frozen_string_literal: true

class Organizations::Aspirations::GoalAssociationsController < Organizations::AssociableGoalAssociationsBaseController
  private

  def load_associable!
    policy_scope(Aspiration).find(params[:aspiration_id])
  end
end
