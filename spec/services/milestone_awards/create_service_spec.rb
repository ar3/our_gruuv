# frozen_string_literal: true

require "rails_helper"

RSpec.describe MilestoneAwards::CreateService do
  let(:organization) { create(:organization) }
  let(:recipient) { create(:teammate, organization: organization) }
  let(:awarder) { create(:teammate, organization: organization) }
  let(:cosigner) { create(:teammate, organization: organization) }
  let(:ability) { create(:ability, company: organization) }

  def typed_name_for(teammate)
    teammate.person.all_names_display_name
  end

  it "creates the requested milestone immediately when co-sign is skipped" do
    result = described_class.call(
      teammate: recipient,
      ability: ability,
      official_level: 1,
      certifying_teammate: awarder,
      created_by_person: awarder.person,
      organization: organization,
      source: :normal,
      awarder_typed_name: typed_name_for(awarder),
      skip_cosign: true,
      certification_note: "Skip path",
      privacy_level: "company"
    )

    expect(result.ok?).to eq(true)
    award = result.value
    expect(award.skipped_awaiting_moderation?).to eq(true)
    expect(recipient.teammate_milestones.where(ability: ability).pluck(:milestone_level)).to contain_exactly(1)
    expect(award.primary_teammate_milestone.milestone_award_id).to eq(award.id)
  end

  it "holds milestones when co-sign is requested" do
    result = described_class.call(
      teammate: recipient,
      ability: ability,
      official_level: 1,
      certifying_teammate: awarder,
      created_by_person: awarder.person,
      organization: organization,
      source: :normal,
      awarder_typed_name: typed_name_for(awarder),
      skip_cosign: false,
      cosign_invitee_ids: [cosigner.id],
      privacy_level: "company"
    )

    expect(result.ok?).to eq(true)
    award = result.value
    expect(award.pending_cosign?).to eq(true)
    expect(award.cosign_invites.pluck(:invitee_teammate_id)).to eq([cosigner.id])
    expect(recipient.teammate_milestones.where(ability: ability)).to be_empty
  end

  it "rejects a mismatched typed name" do
    result = described_class.call(
      teammate: recipient,
      ability: ability,
      official_level: 1,
      certifying_teammate: awarder,
      created_by_person: awarder.person,
      organization: organization,
      source: :normal,
      awarder_typed_name: "Not My Name",
      skip_cosign: true
    )

    expect(result.ok?).to eq(false)
    expect(result.error.to_s).to match(/full name/i)
  end
end
