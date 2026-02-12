require 'rails_helper'

RSpec.describe KudosHelper, type: :helper do
  describe '#kudos_transaction_description_link' do
    context 'when transaction has an observation' do
      let(:organization) { create(:organization) }
      let(:teammate) { create(:company_teammate, organization: organization) }
      let(:observation) { create(:observation, company: organization) }
      let(:transaction) do
        create(:points_exchange_transaction, company_teammate: teammate, organization: organization, observation: observation)
      end

      it 'returns a link to the observation with the description as text' do
        result = helper.kudos_transaction_description_link(transaction)
        expect(result).to include(organization_observation_path(organization, observation))
        expect(result).to include(helper.kudos_transaction_description(transaction))
      end
    end

    context 'when transaction has no observation' do
      let(:organization) { create(:organization) }
      let(:teammate) { create(:company_teammate, organization: organization) }
      let(:transaction) { create(:bank_award_transaction, company_teammate: teammate, organization: organization) }

      it 'returns plain description text without a link' do
        result = helper.kudos_transaction_description_link(transaction)
        expect(result).to eq(helper.kudos_transaction_description(transaction))
        expect(result).not_to include('href=')
      end
    end
  end
end
