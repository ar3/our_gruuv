require 'rails_helper'

RSpec.describe RedemptionTransaction, type: :model do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let(:reward) { create(:kudos_reward, organization: organization, cost_in_points: 100) }
  let(:redemption) { create(:kudos_redemption, organization: organization, company_teammate: teammate, kudos_reward: reward, points_spent: 100) }

  describe 'validations' do
    it 'is valid with proper attributes' do
      transaction = build(:redemption_transaction,
        company_teammate: teammate,
        organization: organization,
        kudos_redemption: redemption,
        points_to_spend_delta: -100)
      expect(transaction).to be_valid
    end

    it 'requires a kudos_redemption' do
      transaction = build(:redemption_transaction, kudos_redemption: nil)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:kudos_redemption_id]).to include("can't be blank")
    end

    it 'requires negative points_to_spend_delta' do
      transaction = build(:redemption_transaction,
        company_teammate: teammate,
        organization: organization,
        kudos_redemption: redemption,
        points_to_spend_delta: 100)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:points_to_spend_delta]).to include("must be negative for redemptions (spending points)")
    end

    it 'requires non-zero points_to_spend_delta' do
      transaction = build(:redemption_transaction,
        company_teammate: teammate,
        organization: organization,
        kudos_redemption: redemption,
        points_to_spend_delta: 0)
      expect(transaction).not_to be_valid
    end
  end

  describe 'instance methods' do
    let(:transaction) do
      create(:redemption_transaction,
        company_teammate: teammate,
        organization: organization,
        kudos_redemption: redemption,
        points_to_spend_delta: -100)
    end

    describe '#redeemer' do
      it 'returns the company_teammate' do
        expect(transaction.redeemer).to eq(teammate)
      end
    end

    describe '#redeemer_name' do
      it 'returns the redeemer display name' do
        expect(transaction.redeemer_name).to eq(teammate.person.display_name)
      end
    end

    describe '#reward' do
      it 'returns the reward through redemption' do
        expect(transaction.reward).to eq(reward)
      end
    end

    describe '#reward_name' do
      it 'returns the reward name' do
        expect(transaction.reward_name).to eq(reward.name)
      end
    end

    describe '#points_spent' do
      it 'returns the absolute value of points_to_spend_delta' do
        expect(transaction.points_spent).to eq(100.0)
      end
    end

    describe '#points_spent_in_dollars' do
      it 'returns the dollar value (10 points = $1)' do
        expect(transaction.points_spent_in_dollars).to eq(10.0)
      end
    end

    describe '#transaction_summary' do
      it 'returns a summary of the transaction' do
        expect(transaction.transaction_summary).to eq("Redeemed 100 points for #{reward.name}")
      end
    end
  end

  describe '#apply_to_ledger!' do
    let!(:ledger) do
      create(:kudos_points_ledger,
        company_teammate: teammate,
        organization: organization,
        points_to_spend: 200)
    end

    let(:transaction) do
      create(:redemption_transaction,
        company_teammate: teammate,
        organization: organization,
        kudos_redemption: redemption,
        points_to_spend_delta: -100)
    end

    it 'deducts points from the ledger' do
      expect { transaction.apply_to_ledger! }.to change { ledger.reload.points_to_spend }.from(200).to(100)
    end

    it 'raises error if insufficient balance' do
      ledger.update!(points_to_spend: 50)
      expect { transaction.apply_to_ledger! }.to raise_error(KudosPointsLedger::InsufficientBalance)
    end
  end
end
