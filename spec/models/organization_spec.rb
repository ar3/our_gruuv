require 'rails_helper'

RSpec.describe Organization, type: :model do
  describe 'associations' do
    it { should belong_to(:parent).class_name('Organization').optional }
    it { should have_many(:children).class_name('Organization').with_foreign_key('parent_id') }
    it { should have_many(:huddles).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:type) }
  end

  describe 'scopes' do
    let!(:company) { Company.create!(name: 'Acme Corp') }
    let!(:team) { Team.create!(name: 'Engineering', parent: company) }

    describe '.companies' do
      it 'returns only companies' do
        expect(Organization.companies).to include(company)
        expect(Organization.companies).not_to include(team)
      end
    end

    describe '.teams' do
      it 'returns only teams' do
        expect(Organization.teams).to include(team)
        expect(Organization.teams).not_to include(company)
      end
    end
  end

  describe 'instance methods' do
    let(:company) { Company.create!(name: 'Acme Corp') }
    let(:team) { Team.create!(name: 'Engineering', parent: company) }

    describe '#company?' do
      it 'returns true for companies' do
        expect(company.company?).to be true
        expect(team.company?).to be false
      end
    end

    describe '#team?' do
      it 'returns true for teams' do
        expect(team.team?).to be true
        expect(company.team?).to be false
      end
    end

    describe '#root_company' do
      it 'returns self for top-level companies' do
        expect(company.root_company).to eq(company)
      end

      it 'returns the root company for teams' do
        expect(team.root_company).to eq(company)
      end

      it 'returns nil for orphaned organizations' do
        # Create a team without a parent (this would normally fail validation)
        orphaned_team = Team.new(name: 'Orphaned Team')
        orphaned_team.save(validate: false) # Skip validation to test the method
        expect(orphaned_team.root_company).to be_nil
      end
    end

    describe '#department_head' do
      it 'returns nil for now (placeholder)' do
        expect(company.department_head).to be_nil
      end
    end
  end
end 