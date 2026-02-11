require 'rails_helper'

RSpec.describe KickbackRewardTransaction, type: :model do
  describe 'validations' do
    let(:organization) { create(:organization) }
    let(:observer_teammate) { create(:company_teammate, organization: organization) }
    let(:observation) { create(:observation, company: organization, observer: observer_teammate.person) }

    it 'requires an observation' do
      transaction = build(:kickback_reward_transaction,
        company_teammate: observer_teammate,
        organization: organization,
        observation: nil)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:observation_id]).to include("can't be blank")
    end

    it 'requires at least one positive delta' do
      transaction = build(:kickback_reward_transaction,
        company_teammate: observer_teammate,
        organization: organization,
        observation: observation,
        points_to_give_delta: 0,
        points_to_spend_delta: 0)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:base]).to include("Must have at least some reward points")
    end

    it 'does not allow negative points_to_give_delta' do
      transaction = build(:kickback_reward_transaction,
        company_teammate: observer_teammate,
        organization: organization,
        observation: observation,
        points_to_give_delta: -5)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:points_to_give_delta]).to include("cannot be negative for kickback rewards")
    end

    it 'does not allow negative points_to_spend_delta' do
      transaction = build(:kickback_reward_transaction,
        company_teammate: observer_teammate,
        organization: organization,
        observation: observation,
        points_to_spend_delta: -5)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:points_to_spend_delta]).to include("cannot be negative for kickback rewards")
    end

    it 'is valid with proper attributes' do
      transaction = build(:kickback_reward_transaction,
        company_teammate: observer_teammate,
        organization: organization,
        observation: observation,
        points_to_give_delta: 5,
        points_to_spend_delta: 0)
      expect(transaction).to be_valid
    end
  end

  describe 'instance methods' do
    let(:organization) { create(:organization) }
    let(:observer_teammate) { create(:company_teammate, organization: organization) }
    let(:observation) { create(:observation, company: organization, observer: observer_teammate.person) }

    let(:transaction) do
      create(:kickback_reward_transaction,
        company_teammate: observer_teammate,
        organization: organization,
        observation: observation,
        points_to_give_delta: 5,
        points_to_spend_delta: 2)
    end

    describe '#observer' do
      it 'returns the observer person' do
        expect(transaction.observer).to eq(observer_teammate.person)
      end
    end

    describe '#observer_name' do
      it 'returns the observer display name' do
        expect(transaction.observer_name).to eq(observer_teammate.person.display_name)
      end
    end

    describe '#reward_summary' do
      it 'returns a summary of the reward' do
        expect(transaction.reward_summary).to eq("5 points to give and 2 points to spend")
      end

      it 'only mentions non-zero amounts' do
        transaction.points_to_spend_delta = 0
        expect(transaction.reward_summary).to eq("5 points to give")
      end
    end
  end
end
