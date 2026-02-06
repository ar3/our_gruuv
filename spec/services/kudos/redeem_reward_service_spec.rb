require 'rails_helper'

RSpec.describe Kudos::RedeemRewardService do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let(:reward) { create(:kudos_reward, organization: organization, cost_in_points: 100) }

  # Give teammate enough points
  let!(:ledger) do
    create(:kudos_points_ledger,
      company_teammate: teammate,
      organization: organization,
      points_to_spend: 200.0)
  end

  describe '.call' do
    context 'with valid redemption' do
      it 'returns a successful result' do
        result = described_class.call(company_teammate: teammate, reward: reward)

        expect(result.ok?).to be true
        expect(result.value[:redemption]).to be_a(KudosRedemption)
        expect(result.value[:transaction]).to be_a(RedemptionTransaction)
      end

      it 'creates a redemption record' do
        expect {
          described_class.call(company_teammate: teammate, reward: reward)
        }.to change(KudosRedemption, :count).by(1)
      end

      it 'creates a redemption transaction' do
        expect {
          described_class.call(company_teammate: teammate, reward: reward)
        }.to change(RedemptionTransaction, :count).by(1)
      end

      it 'deducts points from ledger' do
        expect {
          described_class.call(company_teammate: teammate, reward: reward)
        }.to change { ledger.reload.points_to_spend }.from(200.0).to(100.0)
      end

      it 'creates redemption with correct attributes' do
        result = described_class.call(company_teammate: teammate, reward: reward)
        redemption = result.value[:redemption]

        expect(redemption.company_teammate).to eq(teammate)
        expect(redemption.organization).to eq(organization)
        expect(redemption.kudos_reward).to eq(reward)
        expect(redemption.points_spent).to eq(100.0)
        expect(redemption.status).to eq('pending')
      end

      it 'creates transaction with correct attributes' do
        result = described_class.call(company_teammate: teammate, reward: reward)
        transaction = result.value[:transaction]

        expect(transaction.company_teammate).to eq(teammate)
        expect(transaction.organization).to eq(organization)
        expect(transaction.points_to_spend_delta).to eq(-100.0)
        expect(transaction.kudos_redemption).to eq(result.value[:redemption])
      end

      it 'accepts optional notes' do
        result = described_class.call(company_teammate: teammate, reward: reward, notes: "Test note")
        expect(result.value[:redemption].notes).to eq("Test note")
      end
    end

    context 'when reward is not available' do
      it 'returns error for inactive reward' do
        reward.update!(active: false)
        result = described_class.call(company_teammate: teammate, reward: reward)

        expect(result.ok?).to be false
        expect(result.error).to include("not available")
      end

      it 'returns error for deleted reward' do
        reward.soft_delete!
        result = described_class.call(company_teammate: teammate, reward: reward)

        expect(result.ok?).to be false
        expect(result.error).to include("not available")
      end
    end

    context 'when teammate is in different organization' do
      let(:other_org) { create(:organization) }
      let(:other_teammate) { create(:company_teammate, organization: other_org) }

      it 'returns an error result' do
        result = described_class.call(company_teammate: other_teammate, reward: reward)

        expect(result.ok?).to be false
        expect(result.error).to include("not in the same organization")
      end
    end

    context 'when teammate has insufficient points' do
      before { ledger.update!(points_to_spend: 50.0) }

      it 'returns an error result' do
        result = described_class.call(company_teammate: teammate, reward: reward)

        expect(result.ok?).to be false
        expect(result.error).to include("Insufficient points")
      end

      it 'does not create any records' do
        expect {
          described_class.call(company_teammate: teammate, reward: reward)
        }.not_to change(KudosRedemption, :count)
      end
    end

    context 'when redeeming exact balance' do
      before { ledger.update!(points_to_spend: 100.0) }

      it 'succeeds and reduces balance to zero' do
        result = described_class.call(company_teammate: teammate, reward: reward)

        expect(result.ok?).to be true
        expect(ledger.reload.points_to_spend).to eq(0.0)
      end
    end

    context 'with multiple redemptions' do
      let!(:reward2) { create(:kudos_reward, organization: organization, cost_in_points: 50) }

      it 'allows multiple redemptions if enough points' do
        result1 = described_class.call(company_teammate: teammate, reward: reward)
        result2 = described_class.call(company_teammate: teammate, reward: reward2)

        expect(result1.ok?).to be true
        expect(result2.ok?).to be true
        expect(ledger.reload.points_to_spend).to eq(50.0)
      end

      it 'fails second redemption if not enough points' do
        # Reduce balance so second redemption fails
        ledger.update!(points_to_spend: 150.0)

        result1 = described_class.call(company_teammate: teammate, reward: reward)
        result2 = described_class.call(company_teammate: teammate, reward: reward)

        expect(result1.ok?).to be true
        expect(result2.ok?).to be false
        expect(result2.error).to include("Insufficient points")
      end
    end
  end
end
