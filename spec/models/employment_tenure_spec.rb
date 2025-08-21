require 'rails_helper'

RSpec.describe EmploymentTenure, type: :model do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:position) { create(:position) }
  let(:manager) { create(:person) }

  describe 'associations' do
    it { should belong_to(:person) }
    it { should belong_to(:company).class_name('Organization') }
    it { should belong_to(:position) }
    it { should belong_to(:manager).class_name('Person').optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:started_at) }

    describe 'ended_at validation' do
      it 'allows ended_at to be nil (active employment)' do
        tenure = build(:employment_tenure, ended_at: nil)
        expect(tenure).to be_valid
      end

      it 'requires ended_at to be after started_at' do
        tenure = build(:employment_tenure, started_at: 1.day.ago, ended_at: 2.days.ago)
        expect(tenure).not_to be_valid
        expect(tenure.errors[:ended_at]).to include("must be greater than #{tenure.started_at}")
      end

      it 'allows ended_at to be after started_at' do
        tenure = build(:employment_tenure, started_at: 2.days.ago, ended_at: 1.day.ago)
        expect(tenure).to be_valid
      end
    end
  end

  describe 'overlapping tenures validation' do
    let!(:existing_tenure) do
      create(:employment_tenure, 
        person: person, 
        company: company, 
        started_at: 1.month.ago, 
        ended_at: nil)
    end

    it 'prevents overlapping active tenures for same person and company' do
      overlapping_tenure = build(:employment_tenure, 
        person: person, 
        company: company, 
        started_at: 2.weeks.ago, 
        ended_at: nil)
      
      expect(overlapping_tenure).not_to be_valid
      expect(overlapping_tenure.errors[:base]).to include('Cannot have overlapping active employment tenures for the same person and company')
    end

    it 'allows overlapping tenures for different companies' do
      other_company = create(:organization, :company)
      overlapping_tenure = build(:employment_tenure, 
        person: person, 
        company: other_company, 
        started_at: 2.weeks.ago, 
        ended_at: nil)
      
      expect(overlapping_tenure).to be_valid
    end

    it 'allows overlapping tenures for different people' do
      other_person = create(:person)
      overlapping_tenure = build(:employment_tenure, 
        person: other_person, 
        company: company, 
        started_at: 2.weeks.ago, 
        ended_at: nil)
      
      expect(overlapping_tenure).to be_valid
    end

    it 'allows new tenure after existing tenure ends' do
      existing_tenure.update!(ended_at: 1.week.ago)
      
      new_tenure = build(:employment_tenure, 
        person: person, 
        company: company, 
        started_at: 3.days.ago, 
        ended_at: nil)
      
      expect(new_tenure).to be_valid
    end
  end

  describe 'scopes' do
    let!(:active_tenure) { create(:employment_tenure, ended_at: nil) }
    let!(:inactive_tenure) { create(:employment_tenure, ended_at: 1.day.ago) }

    describe '.active' do
      it 'returns only active tenures' do
        expect(EmploymentTenure.active).to include(active_tenure)
        expect(EmploymentTenure.active).not_to include(inactive_tenure)
      end
    end

    describe '.inactive' do
      it 'returns only inactive tenures' do
        expect(EmploymentTenure.inactive).to include(inactive_tenure)
        expect(EmploymentTenure.inactive).not_to include(active_tenure)
      end
    end

    describe '.most_recent_for_person_and_company' do
      let(:person) { create(:person) }
      let(:company) { create(:organization, :company) }
      let!(:old_tenure) { create(:employment_tenure, person: person, company: company, started_at: 2.years.ago, ended_at: 1.year.ago) }
      let!(:new_tenure) { create(:employment_tenure, person: person, company: company, started_at: 1.year.ago) }

      it 'returns the most recent employment tenure for a person and company' do
        result = EmploymentTenure.most_recent_for_person_and_company(person, company)
        expect(result.first).to eq(new_tenure)
      end
    end
  end

  describe '.most_recent_for' do
    let(:person) { create(:person) }
    let(:company) { create(:organization, :company) }
    let!(:old_tenure) { create(:employment_tenure, person: person, company: company, started_at: 2.years.ago, ended_at: 1.year.ago) }
    let!(:new_tenure) { create(:employment_tenure, person: person, company: company, started_at: 1.year.ago) }

    it 'returns the most recent employment tenure for a person and company' do
      result = EmploymentTenure.most_recent_for(person, company)
      expect(result).to eq(new_tenure)
    end

    it 'returns nil when no employment tenures exist' do
      other_person = create(:person)
      result = EmploymentTenure.most_recent_for(other_person, company)
      expect(result).to be_nil
    end
  end

  describe '#active?' do
    it 'returns true when ended_at is nil' do
      tenure = build(:employment_tenure, ended_at: nil)
      expect(tenure.active?).to be true
    end

    it 'returns false when ended_at is set' do
      tenure = build(:employment_tenure, ended_at: 1.day.ago)
      expect(tenure.active?).to be false
    end
  end

  describe '#inactive?' do
    it 'returns false when ended_at is nil' do
      tenure = build(:employment_tenure, ended_at: nil)
      expect(tenure.inactive?).to be false
    end

    it 'returns true when ended_at is set' do
      tenure = build(:employment_tenure, ended_at: 1.day.ago)
      expect(tenure.inactive?).to be true
    end
  end

  describe 'association includes and queries' do
    let(:person) { create(:person) }
    let(:company) { create(:organization, :company) }
    let!(:tenure) { create(:employment_tenure, person: person, company: company) }

    it 'can include company association correctly' do
      # This test ensures we use the right association name in includes
      result = EmploymentTenure.includes(:company).find(tenure.id)
      expect(result.company.id).to eq(company.id)
      expect(result.company).to be_a(Organization) # Company inherits from Organization
    end

    it 'can include company with other associations' do
      # This test ensures complex includes work correctly
      result = EmploymentTenure.includes(:company, :position, :manager).find(tenure.id)
      expect(result.company.id).to eq(company.id)
      expect(result.position).to eq(tenure.position)
    end

    it 'can query by company association' do
      # This test ensures where clauses work correctly
      result = EmploymentTenure.where(company: company).first
      expect(result).to eq(tenure)
    end

    it 'can access company through the association' do
      # This test ensures the association method works
      expect(tenure.company.id).to eq(company.id)
      expect(tenure.company.name).to eq(company.name)
    end

    it 'prevents using incorrect association names in includes' do
      # This test catches the exact error we encountered
      expect {
        EmploymentTenure.includes(:organization).find(tenure.id)
      }.to raise_error(ActiveRecord::AssociationNotFoundError, /Association named 'organization' was not found/)
    end
  end
end
