# frozen_string_literal: true

module MilestoneAwardsHelper
  def organization_teammate_ability_milestone_award_path_for(organization, award)
    organization_teammate_ability_milestone_award_path(
      organization,
      award.teammate,
      award.ability,
      award
    )
  end

  def organization_teammate_ability_milestone_award_url_for(organization, award)
    organization_teammate_ability_milestone_award_url(
      organization,
      award.teammate,
      award.ability,
      award
    )
  end

  def milestone_award_cosign_outreach_message(award:, open_invitees:)
    first = open_invitees.first&.person
    return nil if first.blank?

    recipient = award.teammate.person
    ability = award.ability
    adjective = milestone_level_display(award.official_milestone_level.to_i)
    url = organization_teammate_ability_milestone_award_url_for(award.organization, award)

    "Hey #{first.casual_name}, I'm proposing that #{recipient.casual_name} has demonstrated #{adjective} of #{ability.display_name}. I've named you as a potential co-signer. Can you check out the following form and let me know if you are willing to co-sign: #{url}"
  end

  # Status hash for awarder / manage-employment cosign response list.
  def milestone_award_cosign_invite_response(award, invite)
    if award.cosigned? && invite.invitee_teammate_id == award.cosigning_teammate_id
      { status: "Co-signed", reason: award.cosigner_reason, badge_class: "text-bg-success" }
    elsif invite.declined?
      { status: "Declined", reason: invite.decline_reason, badge_class: "text-bg-danger" }
    elsif invite.converted_to_feedback?
      { status: "Converted to feedback", reason: nil, badge_class: "text-bg-secondary" }
    else
      { status: "Awaiting response", reason: nil, badge_class: "text-bg-warning" }
    end
  end

  def cosign_organization_teammate_ability_milestone_award_path_for(organization, award)
    cosign_organization_teammate_ability_milestone_award_path(
      organization,
      award.teammate,
      award.ability,
      award
    )
  end

  def decline_organization_teammate_ability_milestone_award_path_for(organization, award)
    decline_organization_teammate_ability_milestone_award_path(
      organization,
      award.teammate,
      award.ability,
      award
    )
  end

  def request_cosign_organization_teammate_ability_milestone_award_path_for(organization, award)
    request_cosign_organization_teammate_ability_milestone_award_path(
      organization,
      award.teammate,
      award.ability,
      award
    )
  end

  def require_cosign_organization_teammate_ability_milestone_award_path_for(organization, award)
    require_cosign_organization_teammate_ability_milestone_award_path(
      organization,
      award.teammate,
      award.ability,
      award
    )
  end
end
