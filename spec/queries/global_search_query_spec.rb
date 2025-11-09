require 'rails_helper'

RSpec.describe GlobalSearchQuery, type: :query do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { CompanyTeammate.create!(person: person, organization: organization) }
  let(:query) { GlobalSearchQuery.new(query: 'test', current_organization: organization, current_teammate: teammate) }

  describe '#call' do
    context 'with empty query' do
      let(:query) { GlobalSearchQuery.new(query: '', current_organization: organization, current_teammate: teammate) }

      it 'returns empty results' do
        results = query.call
        
        expect(results[:people]).to be_empty
        expect(results[:organizations]).to be_empty
        expect(results[:observations]).to be_empty
        expect(results[:assignments]).to be_empty
        expect(results[:abilities]).to be_empty
        expect(results[:total_count]).to eq(0)
      end
    end

    context 'with valid query' do
      it 'returns structured results' do
        results = query.call
        
        expect(results).to have_key(:people)
        expect(results).to have_key(:organizations)
        expect(results).to have_key(:observations)
        expect(results).to have_key(:assignments)
        expect(results).to have_key(:abilities)
        expect(results).to have_key(:total_count)
      end
    end
  end
end
