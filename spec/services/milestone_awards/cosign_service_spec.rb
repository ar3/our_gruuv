# frozen_string_literal: true

require "rails_helper"

RSpec.describe MilestoneAwards::CosignService do
  let(:organization) { create(:organization) }
  let(:recipient) { create(:teammate, organization: organization) }
  let(:awarder) { create(:teammate, organization: organization) }
  let(:cosigner) { create(:teammate, organization: organization) }
  let(:other) { create(:teammate, organization: organization) }
  let(:ability) { create(:ability, company: organization) }

  let(:award) do
    create_result = MilestoneAwards::CreateService.call(
      teammate: recipient,
      ability: ability,
      official_level: 1,
      certifying_teammate: awarder,
      created_by_person: awarder.person,
      organization: organization,
      source: :normal,
      awarder_typed_name: awarder.person.all_names_display_name,
      skip_cosign: false,
      cosign_invitee_ids: [cosigner.id, other.id],
      privacy_level: "company"
    )
    create_result.value
  end

  it "releases the milestone bundle on first Yes and converts leftovers to feedback" do
    result = described_class.call(
      milestone_award: award,
      cosigning_teammate: cosigner,
      typed_name: cosigner.person.all_names_display_name,
      reason: "Seen it consistently"
    )

    expect(result.ok?).to eq(true)
    expect(award.reload.cosigned?).to eq(true)
    expect(recipient.teammate_milestones.where(ability: ability).pluck(:milestone_level)).to contain_exactly(1)

    leftover = award.cosign_invites.find_by!(invitee_teammate_id: other.id)
    expect(leftover.converted_to_feedback?).to eq(true)
    expect(leftover.feedback_request).to be_present
  end

  it "rejects the awarder even if they could otherwise moderate" do
    result = described_class.call(
      milestone_award: award,
      cosigning_teammate: awarder,
      typed_name: awarder.person.all_names_display_name,
      reason: "I am the awarder"
    )

    expect(result.ok?).to eq(false)
    expect(result.error).to include("cannot co-sign an award you created")
    expect(award.reload.cosigned?).to eq(false)
  end

  it "recreates teammate milestones after moderator require-cosign tore them down" do
    moderator = create(:teammate, :employment_manager, organization: organization)
    skipped = MilestoneAwards::CreateService.call(
      teammate: recipient,
      ability: ability,
      official_level: 1,
      certifying_teammate: awarder,
      created_by_person: awarder.person,
      organization: organization,
      source: :normal,
      awarder_typed_name: awarder.person.all_names_display_name,
      skip_cosign: true,
      privacy_level: "company"
    ).value

    MilestoneAwardCosignInvite.create!(milestone_award: skipped, invitee_teammate: cosigner)

    require_result = MilestoneAwards::ModeratorRequireCosignService.call(
      milestone_award: skipped,
      moderator_teammate: moderator
    )
    expect(require_result.ok?).to eq(true)
    expect(recipient.teammate_milestones.where(ability: ability)).to be_empty

    result = described_class.call(
      milestone_award: skipped.reload,
      cosigning_teammate: cosigner,
      typed_name: cosigner.person.all_names_display_name,
      reason: "Seen it consistently"
    )

    expect(result.ok?).to eq(true)
    expect(skipped.reload.cosigned?).to eq(true)
    expect(recipient.teammate_milestones.where(ability: ability).pluck(:milestone_level)).to contain_exactly(1)
    expect(skipped.primary_teammate_milestone.observable_moment).to be_present
  end
end

