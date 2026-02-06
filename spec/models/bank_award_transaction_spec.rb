require 'rails_helper'

RSpec.describe BankAwardTransaction, type: :model do
  describe 'validations' do
    let(:organization) { create(:organization) }
    let(:banker) { create(:company_teammate, organization: organization, can_manage_highlights_rewards: true) }
    let(:recipient) { create(:company_teammate, organization: organization) }

    it 'requires a banker' do
      transaction = build(:bank_award_transaction, company_teammate: recipient, company_teammate_banker: nil)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:company_teammate_banker_id]).to include("can't be blank")
    end

    it 'requires a reason' do
      transaction = build(:bank_award_transaction, company_teammate: recipient, company_teammate_banker: banker, reason: nil)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:reason]).to include("can't be blank")
    end

    it 'requires at least one positive delta' do
      transaction = build(:bank_award_transaction,
        company_teammate: recipient,
        company_teammate_banker: banker,
        points_to_give_delta: 0,
        points_to_spend_delta: 0)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:base]).to include("Must award at least some points (to give or to spend)")
    end

    it 'does not allow negative points_to_give_delta' do
      transaction = build(:bank_award_transaction,
        company_teammate: recipient,
        company_teammate_banker: banker,
        points_to_give_delta: -10)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:points_to_give_delta]).to include("cannot be negative for bank awards")
    end

    it 'does not allow negative points_to_spend_delta' do
      transaction = build(:bank_award_transaction,
        company_teammate: recipient,
        company_teammate_banker: banker,
        points_to_spend_delta: -10)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:points_to_spend_delta]).to include("cannot be negative for bank awards")
    end

    it 'validates banker has permission' do
      non_banker = create(:company_teammate, organization: organization, can_manage_highlights_rewards: false)
      transaction = build(:bank_award_transaction,
        company_teammate: recipient,
        company_teammate_banker: non_banker,
        points_to_give_delta: 10)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:company_teammate_banker]).to include("does not have permission to award points")
    end

    it 'is valid with proper attributes' do
      transaction = build(:bank_award_transaction,
        company_teammate: recipient,
        organization: organization,
        company_teammate_banker: banker,
        points_to_give_delta: 50,
        points_to_spend_delta: 0,
        reason: "Welcome to the team!")
      expect(transaction).to be_valid
    end
  end

  describe 'scopes' do
    let(:organization) { create(:organization) }
    let(:banker) { create(:company_teammate, organization: organization, can_manage_highlights_rewards: true) }
    let(:recipient1) { create(:company_teammate, organization: organization) }
    let(:recipient2) { create(:company_teammate, organization: organization) }

    before do
      create(:bank_award_transaction, company_teammate: recipient1, organization: organization, company_teammate_banker: banker)
      create(:bank_award_transaction, company_teammate: recipient2, organization: organization, company_teammate_banker: banker)
    end

    describe '.by_banker' do
      it 'filters by banker' do
        expect(BankAwardTransaction.by_banker(banker).count).to eq(2)
      end
    end

    describe '.awarded_to' do
      it 'filters by recipient' do
        expect(BankAwardTransaction.awarded_to(recipient1).count).to eq(1)
      end
    end
  end

  describe 'instance methods' do
    let(:organization) { create(:organization) }
    let(:banker) { create(:company_teammate, organization: organization, can_manage_highlights_rewards: true) }
    let(:recipient) { create(:company_teammate, organization: organization) }

    let(:transaction) do
      create(:bank_award_transaction,
        company_teammate: recipient,
        organization: organization,
        company_teammate_banker: banker,
        points_to_give_delta: 50,
        points_to_spend_delta: 25,
        reason: "Great work!")
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

    describe '#banker_name' do
      it 'returns the banker display name' do
        expect(transaction.banker_name).to eq(banker.person.display_name)
      end
    end

    describe '#award_summary' do
      it 'returns a summary of the award' do
        expect(transaction.award_summary).to eq("50.0 points to give and 25.0 points to spend")
      end

      it 'only mentions non-zero amounts' do
        transaction.points_to_spend_delta = 0
        expect(transaction.award_summary).to eq("50.0 points to give")
      end
    end
  end
end
