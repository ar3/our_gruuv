require 'rails_helper'

RSpec.describe PointsExchangeTransaction, type: :model do
  describe 'validations' do
    let(:organization) { create(:organization) }
    let(:recipient) { create(:company_teammate, organization: organization) }
    let(:observation) { create(:observation, company: organization) }

    it 'requires an observation' do
      transaction = build(:points_exchange_transaction,
        company_teammate: recipient,
        organization: organization,
        observation: nil)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:observation_id]).to include("can't be blank")
    end

    it 'requires positive points_to_spend_delta' do
      transaction = build(:points_exchange_transaction,
        company_teammate: recipient,
        organization: organization,
        observation: observation,
        points_to_spend_delta: 0)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:points_to_spend_delta]).to include("must be positive for point exchange")
    end

    it 'is valid with proper attributes' do
      transaction = build(:points_exchange_transaction,
        company_teammate: recipient,
        organization: organization,
        observation: observation,
        points_to_give_delta: 0,
        points_to_spend_delta: 10)
      expect(transaction).to be_valid
    end
  end

  describe 'instance methods' do
    let(:organization) { create(:organization) }
    let(:recipient) { create(:company_teammate, organization: organization) }
    let(:observer_person) { create(:person) }
    let(:observation) { create(:observation, company: organization, observer: observer_person) }

    let(:transaction) do
      create(:points_exchange_transaction,
        company_teammate: recipient,
        organization: organization,
        observation: observation,
        points_to_give_delta: 0,
        points_to_spend_delta: 10)
    end

    describe '#recipient' do
      it 'returns the company_teammate' do
        expect(transaction.recipient).to eq(recipient)
      end
    end

    describe '#recipient_name' do
      it 'returns the recipient display name' do
        expect(transaction.recipient_name).to eq(recipient.person.display_name)
      end
    end

    describe '#observer' do
      it 'returns the observation observer' do
        expect(transaction.observer).to eq(observer_person)
      end
    end

    describe '#from_company_bank?' do
      it 'returns false when no observable moment' do
        expect(transaction.from_company_bank?).to be false
      end

      it 'returns true when observation has observable moment' do
        observation.update!(observable_moment: create(:observable_moment, :new_hire, company: organization))
        expect(transaction.from_company_bank?).to be true
      end
    end

    describe '#from_observer_balance?' do
      it 'returns true when no observable moment' do
        expect(transaction.from_observer_balance?).to be true
      end
    end
  end
end
