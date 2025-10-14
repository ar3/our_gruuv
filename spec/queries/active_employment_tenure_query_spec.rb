require 'rails_helper'

RSpec.describe ActiveEmploymentTenureQuery do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: organization) }

  describe '#initialize' do
    it 'requires person or organization' do
      expect { described_class.new }.to raise_error(ArgumentError, "Must provide person, organization, or both")
    end

    it 'accepts person only' do
      expect { described_class.new(person: person) }.not_to raise_error
    end

    it 'accepts organization only' do
      expect { described_class.new(organization: organization) }.not_to raise_error
    end

    it 'accepts both person and organization' do
      expect { described_class.new(person: person, organization: organization) }.not_to raise_error
    end
  end

  describe '#all' do
    context 'with person and organization' do
      let(:query) { described_class.new(person: person, organization: organization) }

      it 'returns employment tenures for the specific teammate' do
        employment_tenure # Create the tenure
        other_organization = create(:organization)
        other_teammate = create(:teammate, person: person, organization: other_organization)
        other_tenure = create(:employment_tenure, teammate: other_teammate, company: other_organization)

        result = query.all
        expect(result).to include(employment_tenure)
        expect(result).not_to include(other_tenure)
      end

      it 'returns empty relation when teammate does not exist' do
        person_without_teammate = create(:person)
        query = described_class.new(person: person_without_teammate, organization: organization)
        
        result = query.all
        expect(result).to be_empty
      end
    end

    context 'with person only' do
      let(:query) { described_class.new(person: person) }

      it 'returns all active employment tenures for the person' do
        employment_tenure # Create the tenure
        other_organization = create(:organization)
        other_teammate = create(:teammate, person: person, organization: other_organization)
        other_tenure = create(:employment_tenure, teammate: other_teammate, company: other_organization)

        result = query.all
        expect(result).to include(employment_tenure)
        expect(result).to include(other_tenure)
      end
    end

    context 'with organization only' do
      let(:query) { described_class.new(organization: organization) }

      it 'returns all active employment tenures for the organization' do
        employment_tenure # Create the tenure
        other_person = create(:person)
        other_teammate = create(:teammate, person: other_person, organization: organization)
        other_tenure = create(:employment_tenure, teammate: other_teammate, company: organization)

        result = query.all
        expect(result).to include(employment_tenure)
        expect(result).to include(other_tenure)
      end
    end
  end

  describe '#first' do
    let(:query) { described_class.new(person: person, organization: organization) }

    it 'returns the first employment tenure' do
      employment_tenure # Create the tenure
      result = query.first
      expect(result).to eq(employment_tenure)
    end

    it 'returns nil when no tenures exist' do
      person_without_teammate = create(:person)
      query = described_class.new(person: person_without_teammate, organization: organization)
      
      result = query.first
      expect(result).to be_nil
    end
  end
end




