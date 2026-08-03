# frozen_string_literal: true

class PositionSuggestionMilestonePolicy < ApplicationPolicy
  def show?
    admin_bypass? || PositionSuggestionPolicy.new(pundit_user, record.position_suggestion).show?
  end
end
