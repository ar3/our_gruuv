require 'rails_helper'

RSpec.describe ObservableMoment, type: :model do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, organization: company, person: person) }
  let(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: company) }
  
  describe 'associations' do
    it { should belong_to(:momentable) }
    it { should belong_to(:company).class_name('Organization') }
    it { should belong_to(:created_by).class_name('Person') }
    it { should belong_to(:primary_potential_observer).class_name('CompanyTeammate') }
    it { should belong_to(:processed_by_teammate).class_name('CompanyTeammate').optional }
    it { should have_many(:observations).dependent(:nullify) }
  end
  
  describe 'enums' do
    it 'defines moment_type enum with correct values' do
      expect(ObservableMoment.moment_types).to eq({
        'new_hire' => 'new_hire',
        'seat_change' => 'seat_change',
        'ability_milestone' => 'ability_milestone',
        'check_in_completed' => 'check_in_completed',
        'goal_check_in' => 'goal_check_in'
      })
    end
  end
  
  describe 'validations' do
    it { should validate_presence_of(:momentable_type) }
    it { should validate_presence_of(:momentable_id) }
    it { should validate_presence_of(:moment_type) }
    it { should validate_presence_of(:company) }
    it { should validate_presence_of(:created_by) }
    it { should validate_presence_of(:primary_potential_observer) }
    it { should validate_presence_of(:occurred_at) }
  end
  
  describe 'scopes' do
    let!(:moment1) { create(:observable_moment, :new_hire, company: company, occurred_at: 1.day.ago) }
    let!(:moment2) { create(:observable_moment, :seat_change, company: company, occurred_at: 2.days.ago) }
    let!(:moment3) { create(:observable_moment, :new_hire, company: company, processed_at: Time.current) }
    let!(:other_company) { create(:organization, :company) }
    let!(:moment4) { create(:observable_moment, :new_hire, company: other_company) }
    
    describe '.for_company' do
      it 'returns moments for the specified company' do
        expect(ObservableMoment.for_company(company)).to include(moment1, moment2, moment3)
        expect(ObservableMoment.for_company(company)).not_to include(moment4)
      end
    end
    
    describe '.by_type' do
      it 'returns moments of the specified type' do
        expect(ObservableMoment.by_type('new_hire')).to include(moment1, moment3, moment4)
        expect(ObservableMoment.by_type('new_hire')).not_to include(moment2)
      end
    end
    
    describe '.recent' do
      it 'orders by occurred_at descending' do
        expect(ObservableMoment.recent.first).to eq(moment1)
        expect(ObservableMoment.recent.last).to eq(moment2)
      end
    end
    
    describe '.pending' do
      it 'returns only unprocessed moments' do
        expect(ObservableMoment.pending).to include(moment1, moment2, moment4)
        expect(ObservableMoment.pending).not_to include(moment3)
      end
    end
    
    describe '.processed' do
      it 'returns only processed moments' do
        expect(ObservableMoment.processed).to include(moment3)
        expect(ObservableMoment.processed).not_to include(moment1, moment2, moment4)
      end
    end
    
    describe '.for_observer' do
      let(:observer_teammate) { create(:teammate, organization: company) }
      let!(:moment_for_observer) { create(:observable_moment, :new_hire, company: company, primary_potential_observer: observer_teammate) }
      let!(:processed_moment) { create(:observable_moment, :new_hire, company: company, primary_potential_observer: observer_teammate, processed_at: Time.current) }
      
      it 'returns only pending moments for the specified observer' do
        expect(ObservableMoment.for_observer(observer_teammate)).to include(moment_for_observer)
        expect(ObservableMoment.for_observer(observer_teammate)).not_to include(processed_moment, moment1)
      end
    end
  end
  
  describe 'helper methods' do
    let(:moment) { create(:observable_moment, :new_hire, company: company, primary_potential_observer: teammate) }
    
    describe '#processed?' do
      it 'returns true when processed_at is present' do
        expect(moment.processed?).to be false
        moment.update!(processed_at: Time.current)
        expect(moment.processed?).to be true
      end
    end
    
    describe '#observed?' do
      it 'returns true when moment has associated observations' do
        expect(moment.observed?).to be false
        create(:observation, observable_moment: moment, observer: person, company: company)
        expect(moment.observed?).to be true
      end
    end
    
    describe '#ignored?' do
      it 'returns true when processed but not observed' do
        expect(moment.ignored?).to be false
        moment.update!(processed_at: Time.current, processed_by_teammate: teammate)
        expect(moment.ignored?).to be true
        
        create(:observation, observable_moment: moment, observer: person, company: company)
        expect(moment.ignored?).to be false
      end
    end
    
    describe '#display_name' do
      it 'returns appropriate display name for new_hire' do
        moment = create(:observable_moment, :new_hire, company: company)
        expect(moment.display_name).to include('New Hire')
      end
      
      it 'returns appropriate display name for seat_change' do
        moment = create(:observable_moment, :seat_change, company: company)
        expect(moment.display_name).to include('Seat Change')
      end
      
      it 'returns appropriate display name for ability_milestone' do
        milestone = create(:teammate_milestone)
        moment = create(:observable_moment, :ability_milestone, momentable: milestone, company: milestone.ability.organization)
        expect(moment.display_name).to include('Milestone')
      end
    end
    
    describe '#description' do
      it 'returns detailed description for new_hire' do
        moment = create(:observable_moment, :new_hire, company: company)
        expect(moment.description).to be_present
        expect(moment.description).to include('Welcome')
      end
    end
    
    describe '#associated_person' do
      it 'returns the person associated with the moment' do
        moment = create(:observable_moment, :new_hire, company: company)
        expect(moment.associated_person).to eq(moment.momentable.teammate.person)
      end
    end
    
    describe '#associated_teammate' do
      it 'returns the teammate associated with the moment' do
        moment = create(:observable_moment, :new_hire, company: company)
        expect(moment.associated_teammate).to eq(moment.momentable.teammate)
      end
    end
    
    describe '#reassign_to' do
      it 'updates primary_potential_observer' do
        new_observer = create(:teammate, organization: company)
        moment.reassign_to(new_observer)
        expect(moment.reload.primary_potential_observer).to eq(new_observer)
      end
    end
  end
end

