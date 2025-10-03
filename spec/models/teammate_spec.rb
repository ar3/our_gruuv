require 'rails_helper'

RSpec.describe Teammate, type: :model do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:team) { create(:organization, :team, parent: company) }
  
  describe 'associations' do
    it { should belong_to(:person) }
    it { should belong_to(:organization) }
  end
  
  describe 'validations' do
    it 'validates uniqueness of person_id scoped to organization_id' do
      existing_access = create(:teammate, person: person, organization: company)
      duplicate_access = build(:teammate, person: person, organization: company)
      
      expect(duplicate_access).not_to be_valid
      expect(duplicate_access.errors[:person_id]).to include('has already been taken')
    end
  end
  
  describe 'scopes' do
    let(:person2) { create(:person) }
    let(:person3) { create(:person) }
    let(:person4) { create(:person) }
    
    let!(:access1) { create(:teammate, person: person, organization: company) }
    let!(:access2) { create(:teammate, person: person2, organization: team) }
    
    describe '.for_organization_hierarchy' do
      it 'returns access records for organization and all descendants' do
        result = described_class.for_organization_hierarchy(company)
        expect(result).to include(access1, access2)
      end
      
      it 'returns access records for specific organization' do
        result = described_class.for_organization_hierarchy(team)
        expect(result).to include(access2)
      end
    end
    
    describe '.with_employment_management' do
      let!(:employment_access) { create(:teammate, :employment_manager, person: person3, organization: company) }
      
      it 'returns only access records with employment management' do
        result = described_class.with_employment_management
        expect(result).to include(employment_access)
        expect(result).not_to include(access1, access2)
      end
    end
    
    describe '.with_maap_management' do
      let!(:maap_access) { create(:teammate, :maap_manager, person: person4, organization: team) }
      
      it 'returns only access records with MAAP management' do
        result = described_class.with_maap_management
        expect(result).to include(maap_access)
        expect(result).not_to include(access1, access2)
      end
    end
  end
  
  describe 'instance methods' do
    let(:access) { create(:teammate, person: person, organization: company) }
    
    describe '#can_manage_employment?' do
      it 'returns true when can_manage_employment is true' do
        access.update!(can_manage_employment: true)
        expect(access.can_manage_employment?).to be true
      end
      
      it 'returns false when can_manage_employment is false' do
        access.update!(can_manage_employment: false)
        expect(access.can_manage_employment?).to be false
      end
      
      it 'returns false when can_manage_employment is nil' do
        access.update!(can_manage_employment: nil)
        expect(access.can_manage_employment?).to be false
      end
    end
    
    describe '#can_manage_maap?' do
      it 'returns true when can_manage_maap is true' do
        access.update!(can_manage_maap: true)
        expect(access.can_manage_maap?).to be true
      end
      
      it 'returns false when can_manage_maap is false' do
        access.update!(can_manage_maap: false)
        expect(access.can_manage_maap?).to be false
      end
      
      it 'returns false when can_manage_maap is nil' do
        access.update!(can_manage_maap: nil)
        expect(access.can_manage_maap?).to be false
      end
    end
  end
  
  describe 'class methods' do
    let!(:access) { create(:teammate, person: person, organization: company) }
    
    describe '.can_manage_employment?' do
      it 'returns true when person has employment management access' do
        access.update!(can_manage_employment: true)
        expect(described_class.can_manage_employment?(person, company)).to be true
      end
      
      it 'returns false when person does not have employment management access' do
        access.update!(can_manage_employment: false)
        expect(described_class.can_manage_employment?(person, company)).to be false
      end
      
      it 'returns false when no access record exists' do
        access.destroy
        expect(described_class.can_manage_employment?(person, company)).to be false
      end
    end
    
    describe '.can_manage_maap?' do
      it 'returns true when person has MAAP management access' do
        access.update!(can_manage_maap: true)
        expect(described_class.can_manage_maap?(person, company)).to be true
      end
      
      it 'returns false when person does not have MAAP management access' do
        access.update!(can_manage_maap: false)
        expect(described_class.can_manage_maap?(person, company)).to be false
      end
      
      it 'returns false when no access record exists' do
        access.destroy
        expect(described_class.can_manage_maap?(person, company)).to be false
      end
    end
    
    describe '.can_manage_employment_in_hierarchy?' do
      let!(:team_access) { create(:teammate, person: person, organization: team) }
      
      it 'returns true when person has employment management access at organization level' do
        team_access.update!(can_manage_employment: true)
        expect(described_class.can_manage_employment_in_hierarchy?(person, team)).to be true
      end
      
      it 'returns true when person has employment management access at ancestor level' do
        access.update!(can_manage_employment: true)
        expect(described_class.can_manage_employment_in_hierarchy?(person, team)).to be true
      end
      
      it 'returns false when person has no employment management access in hierarchy' do
        access.update!(can_manage_employment: false)
        team_access.update!(can_manage_employment: false)
        expect(described_class.can_manage_employment_in_hierarchy?(person, team)).to be false
      end
    end
    
    describe '.can_manage_maap_in_hierarchy?' do
      let!(:team_access) { create(:teammate, person: person, organization: team) }
      
      it 'returns true when person has MAAP management access at organization level' do
        team_access.update!(can_manage_maap: true)
        expect(described_class.can_manage_maap_in_hierarchy?(person, team)).to be true
      end
      
      it 'returns true when person has MAAP management access at ancestor level' do
        access.update!(can_manage_maap: true)
        expect(described_class.can_manage_maap_in_hierarchy?(person, team)).to be true
      end
      
      it 'returns false when person has no MAAP management access in hierarchy' do
        access.update!(can_manage_maap: false)
        team_access.update!(can_manage_maap: false)
        expect(described_class.can_manage_maap_in_hierarchy?(person, team)).to be false
      end
    end
  end
end
