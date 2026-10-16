# frozen_string_literal: true

# Legacy flat URL redirect → nested teammate / ability / milestone_award path.
class Organizations::MilestoneAwardsController < Organizations::OrganizationNamespaceBaseController
  skip_after_action :verify_authorized, raise: false

  def legacy_redirect
    award = MilestoneAward
      .joins(:teammate)
      .where(teammates: { organization_id: organization.id })
      .find(params[:id])

    redirect_to organization_teammate_ability_milestone_award_path(
      organization,
      award.teammate,
      award.ability,
      award
    ), status: :moved_permanently
  end
end
