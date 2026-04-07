# frozen_string_literal: true

class Organizations::Abilities::GoalAssociationsController < Organizations::AssociableGoalAssociationsBaseController
  private

  def load_associable!
    policy_scope(Ability).find(params[:ability_id])
  end
end
