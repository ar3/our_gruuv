require 'rails_helper'

RSpec.describe KudosPointsLedger, type: :model do
  describe 'associations' do
    it { should belong_to(:company_teammate) }
    it { should belong_to(:organization) }
  end

  describe 'validations' do
    let(:company_teammate) { create(:company_teammate) }

    subject { build(:kudos_points_ledger, company_teammate: company_teammate) }

    it { should validate_uniqueness_of(:company_teammate_id).scoped_to(:organization_id) }
    it { should validate_numericality_of(:points_to_give).only_integer.is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:points_to_spend).only_integer.is_greater_than_or_equal_to(0) }

    context 'integer validation' do
      it 'allows whole numbers' do
        ledger = build(:kudos_points_ledger, company_teammate: company_teammate, points_to_give: 10)
        expect(ledger).to be_valid
      end

      it 'rejects decimals' do
        ledger = build(:kudos_points_ledger, company_teammate: company_teammate, points_to_give: 10.5)
        expect(ledger).not_to be_valid
        expect(ledger.errors[:points_to_give]).to include('must be an integer')
      end

      it 'rejects negative values' do
        ledger = build(:kudos_points_ledger, company_teammate: company_teammate, points_to_give: -1)
        expect(ledger).not_to be_valid
      end
    end
  end

  describe 'scopes' do
    let(:organization) { create(:organization) }
    let(:teammate1) { create(:company_teammate, organization: organization) }
    let(:teammate2) { create(:company_teammate, organization: organization) }

    before do
      create(:kudos_points_ledger, company_teammate: teammate1, organization: organization, points_to_give: 50)
      create(:kudos_points_ledger, company_teammate: teammate2, organization: organization, points_to_give: 0, points_to_spend: 0)
    end

    describe '.for_organization' do
      it 'returns ledgers for the specified organization' do
        expect(KudosPointsLedger.for_organization(organization).count).to eq(2)
      end
    end

    describe '.with_balance' do
      it 'returns only ledgers with points' do
        expect(KudosPointsLedger.with_balance.count).to eq(1)
      end
    end
  end

  describe 'instance methods' do
    let(:ledger) { create(:kudos_points_ledger, points_to_give: 50, points_to_spend: 25) }

    describe '#add_to_give' do
      it 'increments points_to_give' do
        ledger.add_to_give(10)
        expect(ledger.reload.points_to_give).to eq(60)
      end
    end

    describe '#add_to_spend' do
      it 'increments points_to_spend' do
        ledger.add_to_spend(10)
        expect(ledger.reload.points_to_spend).to eq(35)
      end
    end

    describe '#deduct_from_give' do
      it 'decrements points_to_give' do
        ledger.deduct_from_give(10)
        expect(ledger.reload.points_to_give).to eq(40)
      end

      it 'raises InsufficientBalance when not enough points' do
        expect { ledger.deduct_from_give(100) }.to raise_error(KudosPointsLedger::InsufficientBalance)
      end
    end

    describe '#apply_debit_from_give' do
      it 'decrements points_to_give without balance check (allows overdraft)' do
        ledger.apply_debit_from_give(10)
        expect(ledger.reload.points_to_give).to eq(40)
      end

      it 'allows balance to go negative (overdraft)' do
        ledger.update!(points_to_give: 3)
        ledger.apply_debit_from_give(10)
        expect(ledger.reload.points_to_give).to eq(-7)
      end
    end

    describe '#deduct_from_spend' do
      it 'decrements points_to_spend' do
        ledger.deduct_from_spend(10)
        expect(ledger.reload.points_to_spend).to eq(15)
      end

      it 'raises InsufficientBalance when not enough points' do
        expect { ledger.deduct_from_spend(100) }.to raise_error(KudosPointsLedger::InsufficientBalance)
      end
    end

    describe '#can_give?' do
      it 'returns true when enough points' do
        expect(ledger.can_give?(50)).to be true
      end

      it 'returns false when not enough points' do
        expect(ledger.can_give?(100)).to be false
      end
    end

    describe '#can_spend?' do
      it 'returns true when enough points' do
        expect(ledger.can_spend?(25)).to be true
      end

      it 'returns false when not enough points' do
        expect(ledger.can_spend?(100)).to be false
      end
    end

    describe 'dollar value methods' do
      it 'calculates points_to_give_dollar_value correctly' do
        expect(ledger.points_to_give_dollar_value).to eq(5.0)
      end

      it 'calculates points_to_spend_dollar_value correctly' do
        expect(ledger.points_to_spend_dollar_value).to eq(2.5)
      end

      it 'calculates total_dollar_value correctly' do
        expect(ledger.total_dollar_value).to eq(7.5)
      end
    end
  end

  describe '.find_or_create_for' do
    let(:company_teammate) { create(:company_teammate) }
    let(:organization) { company_teammate.organization }

    it 'creates a new ledger if none exists' do
      expect {
        KudosPointsLedger.find_or_create_for(company_teammate, organization)
      }.to change(KudosPointsLedger, :count).by(1)
    end

    it 'returns existing ledger if one exists' do
      existing = create(:kudos_points_ledger, company_teammate: company_teammate, organization: organization)
      found = KudosPointsLedger.find_or_create_for(company_teammate, organization)
      expect(found).to eq(existing)
    end
  end
end
