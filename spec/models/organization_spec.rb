require 'rails_helper'

RSpec.describe Organization, type: :model do
  let(:company) { create(:organization, name: 'Acme Corp', type: 'Company') }
  let(:team) { create(:organization, name: 'Engineering', type: 'Team', parent: company) }
  let(:subteam) { create(:organization, name: 'Frontend', type: 'Team', parent: team) }

  describe '#display_name' do
    it 'returns just the name for organizations without parents' do
      expect(company.display_name).to eq('Acme Corp')
    end

    it 'returns hierarchical name for organizations with parents' do
      expect(team.display_name).to eq('Acme Corp > Engineering')
    end

    it 'returns full hierarchical path for deeply nested organizations' do
      expect(subteam.display_name).to eq('Acme Corp > Engineering > Frontend')
    end

    it 'handles multiple levels of nesting correctly' do
      department = create(:organization, name: 'Product', type: 'Team', parent: company)
      squad = create(:organization, name: 'Mobile', type: 'Team', parent: department)
      
      expect(squad.display_name).to eq('Acme Corp > Product > Mobile')
    end
  end

  describe '#company?' do
    it 'returns true for Company type' do
      expect(company.company?).to be true
    end

    it 'returns false for Team type' do
      expect(team.company?).to be false
    end
  end

  describe '#team?' do
    it 'returns true for Team type' do
      expect(team.team?).to be true
    end

    it 'returns false for Company type' do
      expect(company.team?).to be false
    end
  end

  describe '#root_company' do
    it 'returns self for company without parent' do
      expect(company.root_company).to eq(company)
    end

    it 'returns parent company for team' do
      expect(team.root_company).to eq(company)
    end

    it 'returns root company for deeply nested team' do
      expect(subteam.root_company).to eq(company)
    end
  end
end 