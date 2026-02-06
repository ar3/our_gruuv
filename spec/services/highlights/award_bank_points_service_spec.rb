require 'rails_helper'

RSpec.describe Highlights::AwardBankPointsService do
  let(:organization) { create(:organization) }
  let(:banker) { create(:company_teammate, organization: organization, can_manage_highlights_rewards: true) }
  let(:recipient) { create(:company_teammate, organization: organization) }

  describe '.call' do
    context 'with valid parameters' do
      it 'creates a bank award transaction' do
        expect {
          described_class.call(
            banker: banker,
            recipient: recipient,
            points_to_give: 50,
            points_to_spend: 25,
            reason: "Welcome to the team!"
          )
        }.to change(BankAwardTransaction, :count).by(1)
      end

      it 'returns a successful result' do
        result = described_class.call(
          banker: banker,
          recipient: recipient,
          points_to_give: 50,
          reason: "Great work!"
        )

        expect(result.ok?).to be true
        expect(result.value).to be_a(BankAwardTransaction)
      end

      it 'applies the transaction to the ledger' do
        result = described_class.call(
          banker: banker,
          recipient: recipient,
          points_to_give: 50,
          points_to_spend: 25,
          reason: "Welcome!"
        )

        ledger = recipient.highlights_ledger.reload
        expect(ledger.points_to_give).to eq(50)
        expect(ledger.points_to_spend).to eq(25)
      end

      it 'normalizes points to 0.5 increments (rounds up)' do
        result = described_class.call(
          banker: banker,
          recipient: recipient,
          points_to_give: 10.3,
          points_to_spend: 5.1,
          reason: "Test rounding"
        )

        expect(result.ok?).to be true
        expect(result.value.points_to_give_delta).to eq(10.5)
        expect(result.value.points_to_spend_delta).to eq(5.5)
      end

      it 'handles string inputs for points' do
        result = described_class.call(
          banker: banker,
          recipient: recipient,
          points_to_give: "25",
          points_to_spend: "10",
          reason: "String test"
        )

        expect(result.ok?).to be true
        expect(result.value.points_to_give_delta).to eq(25.0)
        expect(result.value.points_to_spend_delta).to eq(10.0)
      end
    end

    context 'when banker lacks permission' do
      let(:non_banker) { create(:company_teammate, organization: organization, can_manage_highlights_rewards: false) }

      it 'returns an error result' do
        result = described_class.call(
          banker: non_banker,
          recipient: recipient,
          points_to_give: 50,
          reason: "Should fail"
        )

        expect(result.ok?).to be false
        expect(result.error).to include("permission")
      end
    end

    context 'when banker and recipient are in different organizations' do
      let(:other_org) { create(:organization) }
      let(:other_recipient) { create(:company_teammate, organization: other_org) }

      it 'returns an error result' do
        result = described_class.call(
          banker: banker,
          recipient: other_recipient,
          points_to_give: 50,
          reason: "Should fail"
        )

        expect(result.ok?).to be false
        expect(result.error).to include("same organization")
      end
    end

    context 'when no points are specified' do
      it 'returns an error result' do
        result = described_class.call(
          banker: banker,
          recipient: recipient,
          points_to_give: 0,
          points_to_spend: 0,
          reason: "No points"
        )

        expect(result.ok?).to be false
      end
    end

    context 'when reason is missing' do
      it 'returns an error result' do
        result = described_class.call(
          banker: banker,
          recipient: recipient,
          points_to_give: 50,
          reason: ""
        )

        expect(result.ok?).to be false
        expect(result.error).to include("Reason")
      end
    end
  end
end
