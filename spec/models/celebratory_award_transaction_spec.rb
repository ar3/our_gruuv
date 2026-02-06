require 'rails_helper'

RSpec.describe CelebratoryAwardTransaction, type: :model do
  describe 'validations' do
    let(:organization) { create(:organization) }
    let(:recipient) { create(:company_teammate, organization: organization) }
    let(:observable_moment) { create(:observable_moment, :new_hire, company: organization, primary_potential_observer: recipient) }

    it 'requires an observable_moment' do
      transaction = build(:celebratory_award_transaction,
        company_teammate: recipient,
        organization: organization,
        observable_moment: nil)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:observable_moment_id]).to include("can't be blank")
    end

    it 'requires at least one positive delta' do
      transaction = build(:celebratory_award_transaction,
        company_teammate: recipient,
        organization: organization,
        observable_moment: observable_moment,
        points_to_give_delta: 0,
        points_to_spend_delta: 0)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:base]).to include("Must award at least some points (to give or to spend)")
    end

    it 'does not allow negative points_to_give_delta' do
      transaction = build(:celebratory_award_transaction,
        company_teammate: recipient,
        organization: organization,
        observable_moment: observable_moment,
        points_to_give_delta: -10)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:points_to_give_delta]).to include("cannot be negative for celebratory awards")
    end

    it 'does not allow negative points_to_spend_delta' do
      transaction = build(:celebratory_award_transaction,
        company_teammate: recipient,
        organization: organization,
        observable_moment: observable_moment,
        points_to_spend_delta: -10)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:points_to_spend_delta]).to include("cannot be negative for celebratory awards")
    end

    it 'is valid with proper attributes' do
      transaction = build(:celebratory_award_transaction,
        company_teammate: recipient,
        organization: organization,
        observable_moment: observable_moment,
        points_to_give_delta: 50,
        points_to_spend_delta: 25)
      expect(transaction).to be_valid
    end
  end

  describe 'instance methods' do
    let(:organization) { create(:organization) }
    let(:recipient) { create(:company_teammate, organization: organization) }
    let(:observable_moment) { create(:observable_moment, :new_hire, company: organization, primary_potential_observer: recipient) }

    let(:transaction) do
      create(:celebratory_award_transaction,
        company_teammate: recipient,
        organization: organization,
        observable_moment: observable_moment,
        points_to_give_delta: 50,
        points_to_spend_delta: 25)
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

    describe '#moment_type' do
      it 'returns the observable moment type' do
        expect(transaction.moment_type).to eq('new_hire')
      end
    end

    describe '#moment_display_name' do
      it 'returns the observable moment display name' do
        expect(transaction.moment_display_name).to include('New Hire')
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

    describe '#reason' do
      it 'returns a generated reason' do
        expect(transaction.reason).to include("Celebratory award for:")
      end
    end
  end
end
