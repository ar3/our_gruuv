# frozen_string_literal: true

require "rails_helper"

RSpec.describe MilestoneAwards::ModeratorRequireCosignService do
  let(:organization) { create(:organization) }
  let(:recipient) { create(:teammate, organization: organization) }
  let(:awarder) { create(:teammate, :employment_manager, organization: organization) }
  let(:cosigner) { create(:teammate, organization: organization) }
  let(:ability) { create(:ability, company: organization) }

  let(:skipped_award) do
    MilestoneAwards::CreateService.call(
      teammate: recipient,
      ability: ability,
      official_level: 1,
      certifying_teammate: awarder,
      created_by_person: awarder.person,
      organization: organization,
      source: :normal,
      awarder_typed_name: awarder.person.all_names_display_name,
      skip_cosign: true,
      certification_note: "Skip path",
      privacy_level: "company"
    ).value
  end

  it "destroys teammate milestones and their observable moments when requiring co-sign" do
    award = skipped_award
    milestones = award.teammate_milestones.to_a
    expect(milestones).not_to be_empty

    moment_ids = milestones.filter_map { |tm| tm.observable_moment&.id }
    expect(moment_ids).not_to be_empty

    result = described_class.call(
      milestone_award: award,
      moderator_teammate: awarder
    )

    expect(result.ok?).to eq(true)
    expect(award.reload.requires_cosign_after_moderation?).to eq(true)
    expect(award.teammate_milestones).to be_empty
    expect(recipient.teammate_milestones.where(ability: ability)).to be_empty
    expect(TeammateMilestone.where(id: milestones.map(&:id))).to be_empty
    expect(ObservableMoment.where(id: moment_ids)).to be_empty
  end

  it "rejects when the award is not a skipped award awaiting moderation" do
    pending = MilestoneAwards::CreateService.call(
      teammate: recipient,
      ability: ability,
      official_level: 1,
      certifying_teammate: awarder,
      created_by_person: awarder.person,
      organization: organization,
      source: :normal,
      awarder_typed_name: awarder.person.all_names_display_name,
      skip_cosign: false,
      cosign_invitee_ids: [cosigner.id],
      privacy_level: "company"
    ).value

    result = described_class.call(
      milestone_award: pending,
      moderator_teammate: awarder
    )

    expect(result.ok?).to eq(false)
    expect(result.error).to include("Only skipped awards")
  end
end
