require 'rails_helper'

RSpec.describe Highlights::AwardCelebratoryPointsService do
  let(:organization) { create(:organization) }
  let(:recipient) { create(:company_teammate, organization: organization) }

  describe '.call' do
    context 'with a new_hire moment' do
      let(:employment_tenure) { create(:employment_tenure, company: organization, teammate: recipient) }
      let(:observable_moment) do
        create(:observable_moment,
          company: organization,
          momentable: employment_tenure,
          primary_potential_observer: recipient,
          moment_type: :new_hire)
      end

      it 'creates a celebratory award transaction' do
        expect {
          described_class.call(observable_moment: observable_moment)
        }.to change(CelebratoryAwardTransaction, :count).by(1)
      end

      it 'returns a successful result' do
        result = described_class.call(observable_moment: observable_moment)

        expect(result.ok?).to be true
        expect(result.value).to be_a(CelebratoryAwardTransaction)
      end

      it 'applies the transaction to the ledger' do
        described_class.call(observable_moment: observable_moment)

        ledger = recipient.highlights_ledger.reload
        expect(ledger.points_to_give).to eq(50.0)  # Default for new_hire
        expect(ledger.points_to_spend).to eq(25.0)
      end

      it 'uses default point configuration' do
        result = described_class.call(observable_moment: observable_moment)

        expect(result.value.points_to_give_delta).to eq(50.0)
        expect(result.value.points_to_spend_delta).to eq(25.0)
      end
    end

    context 'with organization-specific configuration' do
      let(:employment_tenure) { create(:employment_tenure, company: organization, teammate: recipient) }
      let(:observable_moment) do
        create(:observable_moment,
          company: organization,
          momentable: employment_tenure,
          primary_potential_observer: recipient,
          moment_type: :new_hire)
      end

      before do
        organization.update!(highlights_celebratory_config: {
          'new_hire' => { 'points_to_give' => 100, 'points_to_spend' => 50 }
        })
      end

      it 'uses organization-specific configuration' do
        result = described_class.call(observable_moment: observable_moment)

        expect(result.value.points_to_give_delta).to eq(100.0)
        expect(result.value.points_to_spend_delta).to eq(50.0)
      end
    end

    context 'when points were already awarded' do
      let(:employment_tenure) { create(:employment_tenure, company: organization, teammate: recipient) }
      let(:observable_moment) do
        create(:observable_moment,
          company: organization,
          momentable: employment_tenure,
          primary_potential_observer: recipient,
          moment_type: :new_hire)
      end

      before do
        create(:celebratory_award_transaction,
          company_teammate: recipient,
          organization: organization,
          observable_moment: observable_moment)
      end

      it 'returns an error result' do
        result = described_class.call(observable_moment: observable_moment)

        expect(result.ok?).to be false
        expect(result.error).to include("already awarded")
      end

      it 'does not create a duplicate transaction' do
        expect {
          described_class.call(observable_moment: observable_moment)
        }.not_to change(CelebratoryAwardTransaction, :count)
      end
    end

    context 'with different moment types' do
      let(:ability) { create(:ability, company: organization) }
      let(:teammate_milestone) do
        create(:teammate_milestone,
          teammate: recipient,
          ability: ability,
          milestone_level: 1,
          certifying_teammate: recipient)
      end
      let(:observable_moment) do
        create(:observable_moment,
          company: organization,
          momentable: teammate_milestone,
          primary_potential_observer: recipient,
          moment_type: :ability_milestone)
      end

      it 'uses correct defaults for ability_milestone' do
        result = described_class.call(observable_moment: observable_moment)

        expect(result.ok?).to be true
        expect(result.value.points_to_give_delta).to eq(20.0)
        expect(result.value.points_to_spend_delta).to eq(10.0)
      end
    end

    context 'when no associated teammate' do
      let(:employment_tenure) { create(:employment_tenure, company: organization, teammate: recipient) }
      let(:observable_moment) do
        create(:observable_moment, :new_hire,
          company: organization,
          momentable: employment_tenure,
          primary_potential_observer: recipient)
      end

      before do
        # Stub associated_teammate to return nil to simulate edge case
        allow(observable_moment).to receive(:associated_teammate).and_return(nil)
      end

      it 'returns an error result' do
        result = described_class.call(observable_moment: observable_moment)

        expect(result.ok?).to be false
        expect(result.error).to include("No associated teammate")
      end
    end
  end
end
