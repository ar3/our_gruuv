# frozen_string_literal: true

class Organizations::GoalImpactScannerController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :show

  def show
    authorize company, :view_goals?

    @goals = policy_scope(Goal)
    @goals = Goals::FilterQuery.new(@goals).call(show_deleted: false, show_completed: false)
    @goals = @goals.where(privacy_level: "everyone_in_company")
                   .includes(:creator, :owner, :goal_check_ins)

    @hierarchy = Goals::ImpactScannerQuery.new(
      goals: @goals,
      current_person: current_person,
      organization: @organization
    ).call
    @root_goals = @hierarchy[:root_goals]
  end
end
