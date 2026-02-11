require 'rails_helper'

RSpec.describe KudosTransaction, type: :model do
  describe 'associations' do
    it { should belong_to(:company_teammate) }
    it { should belong_to(:organization) }
    it { should belong_to(:observation).optional }
    it { should belong_to(:company_teammate_banker).class_name('CompanyTeammate').optional }
    it { should belong_to(:triggering_transaction).class_name('KudosTransaction').optional }
  end

  describe 'validations' do
    describe 'integer validation' do
      let(:transaction) { build(:kudos_transaction) }

      it 'allows whole numbers for points_to_give_delta' do
        transaction.points_to_give_delta = 10
        expect(transaction).to be_valid
      end

      it 'rejects decimals for points_to_give_delta' do
        transaction.points_to_give_delta = 10.5
        expect(transaction).not_to be_valid
        expect(transaction.errors[:points_to_give_delta]).to include('must be an integer')
      end

      it 'allows negative integers' do
        transaction.points_to_give_delta = -5
        expect(transaction).to be_valid
      end
    end
  end

  describe 'scopes' do
    let(:organization) { create(:organization) }
    let(:teammate) { create(:company_teammate, organization: organization) }

    before do
      create(:kudos_transaction, company_teammate: teammate, organization: organization, created_at: 1.day.ago)
      create(:kudos_transaction, company_teammate: teammate, organization: organization, created_at: 2.days.ago)
      create(:kudos_transaction, company_teammate: teammate, organization: organization, created_at: 3.days.ago)
    end

    describe '.recent' do
      it 'orders by created_at desc' do
        transactions = KudosTransaction.recent
        expect(transactions.first.created_at).to be > transactions.last.created_at
      end
    end

    describe '.by_teammate' do
      it 'filters by company_teammate' do
        expect(KudosTransaction.by_teammate(teammate).count).to eq(3)
      end
    end

    describe '.for_organization' do
      it 'filters by organization' do
        expect(KudosTransaction.for_organization(organization).count).to eq(3)
      end
    end
  end

  describe '#apply_to_ledger!' do
    let(:company_teammate) { create(:company_teammate) }
    let(:organization) { company_teammate.organization }
    let!(:ledger) { create(:kudos_points_ledger, company_teammate: company_teammate, organization: organization, points_to_give: 50, points_to_spend: 25) }

    context 'with positive deltas' do
      let(:transaction) { build(:kudos_transaction, company_teammate: company_teammate, organization: organization, points_to_give_delta: 10, points_to_spend_delta: 5) }

      it 'adds points to the ledger' do
        transaction.save!
        transaction.apply_to_ledger!
        ledger.reload
        expect(ledger.points_to_give).to eq(60)
        expect(ledger.points_to_spend).to eq(30)
      end
    end

    context 'with negative deltas' do
      let(:transaction) { build(:kudos_transaction, company_teammate: company_teammate, organization: organization, points_to_give_delta: -10, points_to_spend_delta: -5) }

      it 'deducts points from the ledger' do
        transaction.save!
        transaction.apply_to_ledger!
        ledger.reload
        expect(ledger.points_to_give).to eq(40)
        expect(ledger.points_to_spend).to eq(20)
      end
    end

    context 'when ledger does not exist' do
      let(:new_teammate) { create(:company_teammate, organization: organization) }
      let(:transaction) { build(:kudos_transaction, company_teammate: new_teammate, organization: organization, points_to_give_delta: 10) }

      it 'creates a ledger and applies the transaction' do
        transaction.save!
        expect { transaction.apply_to_ledger! }.to change(KudosPointsLedger, :count).by(1)
        new_ledger = new_teammate.kudos_points_ledger
        expect(new_ledger.points_to_give).to eq(10)
      end
    end
  end

  describe '#transaction_type_display' do
    it 'returns formatted type name' do
      transaction = build(:bank_award_transaction)
      expect(transaction.transaction_type_display).to eq('Bank Award')
    end
  end

  describe '#net_points_change' do
    it 'sums give and spend deltas' do
      transaction = build(:kudos_transaction, points_to_give_delta: 10, points_to_spend_delta: 5)
      expect(transaction.net_points_change).to eq(15)
    end

    it 'handles nil deltas' do
      transaction = build(:kudos_transaction, points_to_give_delta: nil, points_to_spend_delta: nil)
      expect(transaction.net_points_change).to eq(0)
    end
  end
end
