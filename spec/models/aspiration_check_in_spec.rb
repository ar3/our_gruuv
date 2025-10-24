require 'rails_helper'

RSpec.describe AspirationCheckIn, type: :model do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:aspiration) { create(:aspiration, organization: organization) }
  
  describe 'associations' do
    it { should belong_to(:teammate) }
    it { should belong_to(:aspiration) }
    it { should belong_to(:finalized_by).class_name('Person').optional }
    it { should belong_to(:maap_snapshot).optional }
  end
  
  describe 'validations' do
    it { should validate_presence_of(:check_in_started_on) }
    
    it 'allows nil employee_rating' do
      check_in = build(:aspiration_check_in, employee_rating: nil)
      expect(check_in).to be_valid
    end
  end
  
  describe 'enums' do
    it 'defines employee_rating enum' do
      expect(AspirationCheckIn.employee_ratings).to eq({
        'working_to_meet' => 'working_to_meet',
        'meeting' => 'meeting', 
        'exceeding' => 'exceeding'
      })
    end
    
    it 'defines manager_rating enum' do
      expect(AspirationCheckIn.manager_ratings).to eq({
        'working_to_meet' => 'working_to_meet',
        'meeting' => 'meeting',
        'exceeding' => 'exceeding'
      })
    end
    
    it 'defines official_rating enum' do
      expect(AspirationCheckIn.official_ratings).to eq({
        'working_to_meet' => 'working_to_meet',
        'meeting' => 'meeting',
        'exceeding' => 'exceeding'
      })
    end
  end
  
  describe 'scopes' do
    let!(:open_check_in) { create(:aspiration_check_in, teammate: teammate, aspiration: aspiration, official_check_in_completed_at: nil) }
    let!(:closed_check_in) { create(:aspiration_check_in, teammate: teammate, aspiration: aspiration, official_check_in_completed_at: 1.day.ago) }
    
    describe '.open' do
      it 'returns only open check-ins' do
        expect(AspirationCheckIn.open).to include(open_check_in)
        expect(AspirationCheckIn.open).not_to include(closed_check_in)
      end
    end
    
    describe '.closed' do
      it 'returns only closed check-ins' do
        expect(AspirationCheckIn.closed).to include(closed_check_in)
        expect(AspirationCheckIn.closed).not_to include(open_check_in)
      end
    end
    
    describe '.ready_for_finalization' do
      let(:different_aspiration) { create(:aspiration, organization: organization) }
      let!(:ready_check_in) { create(:aspiration_check_in, teammate: teammate, aspiration: different_aspiration, employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, official_check_in_completed_at: nil) }
      
      it 'returns check-ins ready for finalization' do
        expect(AspirationCheckIn.ready_for_finalization).to include(ready_check_in)
        expect(AspirationCheckIn.ready_for_finalization).not_to include(open_check_in)
      end
    end
  end
  
  describe 'instance methods' do
    let(:check_in) { create(:aspiration_check_in, teammate: teammate, aspiration: aspiration) }
    
    describe '#open?' do
      it 'returns true when official_check_in_completed_at is nil' do
        check_in.update!(official_check_in_completed_at: nil)
        expect(check_in.open?).to be true
      end
      
      it 'returns false when official_check_in_completed_at is present' do
        check_in.update!(official_check_in_completed_at: Time.current)
        expect(check_in.open?).to be false
      end
    end
    
    describe '#ready_for_finalization?' do
      it 'returns true when both employee and manager completed but not officially' do
        check_in.update!(employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, official_check_in_completed_at: nil)
        expect(check_in.ready_for_finalization?).to be true
      end
      
      it 'returns false when employee not completed' do
        check_in.update!(employee_completed_at: nil, manager_completed_at: 1.day.ago, official_check_in_completed_at: nil)
        expect(check_in.ready_for_finalization?).to be false
      end
      
      it 'returns false when manager not completed' do
        check_in.update!(employee_completed_at: 1.day.ago, manager_completed_at: nil, official_check_in_completed_at: nil)
        expect(check_in.ready_for_finalization?).to be false
      end
      
      it 'returns false when already officially completed' do
        check_in.update!(employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, official_check_in_completed_at: 1.day.ago)
        expect(check_in.ready_for_finalization?).to be false
      end
    end
    
    describe '#previous_finalized_check_in' do
      let!(:old_check_in) { create(:aspiration_check_in, teammate: teammate, aspiration: aspiration, official_check_in_completed_at: 1.month.ago) }
      let!(:newer_check_in) { create(:aspiration_check_in, teammate: teammate, aspiration: aspiration, official_check_in_completed_at: 1.week.ago) }
      
      it 'returns the most recent finalized check-in for the same teammate and aspiration' do
        expect(check_in.previous_finalized_check_in).to eq(newer_check_in)
      end
    end
    
    describe '#previous_check_in_summary' do
      let!(:previous_check_in) { create(:aspiration_check_in, teammate: teammate, aspiration: aspiration, official_check_in_completed_at: 1.week.ago, official_rating: 'meeting') }
      
      it 'returns formatted summary of previous check-in' do
        expect(check_in.previous_check_in_summary).to eq("last finalized on #{previous_check_in.official_check_in_completed_at.to_date} with rating of Meeting")
      end
      
      it 'returns nil when no previous check-in exists' do
        different_aspiration = create(:aspiration, organization: organization)
        check_in_with_no_history = create(:aspiration_check_in, teammate: teammate, aspiration: different_aspiration)
        expect(check_in_with_no_history.previous_check_in_summary).to be_nil
      end
    end

    describe 'completion tracking' do
      describe '#complete_employee_side!' do
        it 'marks employee side as completed' do
          expect(check_in.employee_completed?).to be false
          
          check_in.complete_employee_side!
          
          expect(check_in.employee_completed?).to be true
          expect(check_in.employee_completed_at).to be_present
        end

        it 'updates ready_for_finalization status when manager already completed' do
          manager = create(:person)
          check_in.complete_manager_side!(completed_by: manager)
          expect(check_in.ready_for_finalization?).to be false
          
          check_in.complete_employee_side!
          
          expect(check_in.ready_for_finalization?).to be true
        end
      end

      describe '#complete_manager_side!' do
        it 'marks manager side as completed' do
          manager = create(:person)
          expect(check_in.manager_completed?).to be false

          check_in.complete_manager_side!(completed_by: manager)
          
          expect(check_in.manager_completed?).to be true
          expect(check_in.manager_completed_at).to be_present
          expect(check_in.manager_completed_by).to eq(manager)
        end

        it 'updates ready_for_finalization status when employee already completed' do
          check_in.complete_employee_side!
          expect(check_in.ready_for_finalization?).to be false
          
          manager = create(:person)
          check_in.complete_manager_side!(completed_by: manager)
          
          expect(check_in.ready_for_finalization?).to be true
        end
      end

      describe '#uncomplete_employee_side!' do
        it 'unmarks employee side as completed' do
          check_in.complete_employee_side!
          expect(check_in.employee_completed?).to be true
          
          check_in.uncomplete_employee_side!
          
          expect(check_in.employee_completed?).to be false
          expect(check_in.employee_completed_at).to be_nil
        end

        it 'updates ready_for_finalization status when manager completed' do
          manager = create(:person)
          check_in.complete_employee_side!
          check_in.complete_manager_side!(completed_by: manager)
          expect(check_in.ready_for_finalization?).to be true
          
          check_in.uncomplete_employee_side!
          
          expect(check_in.ready_for_finalization?).to be false
        end
      end

      describe '#uncomplete_manager_side!' do
        it 'unmarks manager side as completed' do
          manager = create(:person)
          check_in.complete_manager_side!(completed_by: manager)
          expect(check_in.manager_completed?).to be true
          
          check_in.uncomplete_manager_side!
          
          expect(check_in.manager_completed?).to be false
          expect(check_in.manager_completed_at).to be_nil
          expect(check_in.manager_completed_by).to be_nil
        end

        it 'updates ready_for_finalization status when employee completed' do
          check_in.complete_employee_side!
          manager = create(:person)
          check_in.complete_manager_side!(completed_by: manager)
          expect(check_in.ready_for_finalization?).to be true
          
          check_in.uncomplete_manager_side!
          
          expect(check_in.ready_for_finalization?).to be false
        end
      end

      describe 'completion state transitions' do
        it 'handles multiple complete/uncomplete cycles' do
          manager = create(:person)
          
          # Complete both sides
          check_in.complete_employee_side!
          check_in.complete_manager_side!(completed_by: manager)
          expect(check_in.ready_for_finalization?).to be true
          
          # Uncomplete employee side
          check_in.uncomplete_employee_side!
          expect(check_in.ready_for_finalization?).to be false
          expect(check_in.employee_completed?).to be false
          expect(check_in.manager_completed?).to be true
          
          # Complete employee side again
          check_in.complete_employee_side!
          expect(check_in.ready_for_finalization?).to be true
          
          # Uncomplete manager side
          check_in.uncomplete_manager_side!
          expect(check_in.ready_for_finalization?).to be false
          expect(check_in.employee_completed?).to be true
          expect(check_in.manager_completed?).to be false
          
          # Complete manager side again
          check_in.complete_manager_side!(completed_by: manager)
          expect(check_in.ready_for_finalization?).to be true
        end
      end
    end
  end
  
  describe 'class methods' do
    describe '.find_or_create_open_for' do
      context 'when no open check-in exists' do
        it 'creates a new open check-in' do
          expect {
            AspirationCheckIn.find_or_create_open_for(teammate, aspiration)
          }.to change(AspirationCheckIn, :count).by(1)
          
          check_in = AspirationCheckIn.last
          expect(check_in.teammate).to eq(teammate)
          expect(check_in.aspiration).to eq(aspiration)
          expect(check_in.check_in_started_on).to eq(Date.current)
          expect(check_in.official_check_in_completed_at).to be_nil
        end
      end
      
      context 'when open check-in already exists' do
        let!(:existing_check_in) { create(:aspiration_check_in, teammate: teammate, aspiration: aspiration, official_check_in_completed_at: nil) }
        
        it 'returns the existing open check-in' do
          expect {
            result = AspirationCheckIn.find_or_create_open_for(teammate, aspiration)
            expect(result).to eq(existing_check_in)
          }.not_to change(AspirationCheckIn, :count)
        end
      end
    end
  end
  
  describe 'validation' do
    it 'prevents multiple open check-ins per teammate per aspiration' do
      create(:aspiration_check_in, teammate: teammate, aspiration: aspiration, official_check_in_completed_at: nil)
      
      duplicate_check_in = build(:aspiration_check_in, teammate: teammate, aspiration: aspiration, official_check_in_completed_at: nil)
      expect(duplicate_check_in).not_to be_valid
      expect(duplicate_check_in.errors[:base]).to include("Only one open aspiration check-in allowed per teammate per aspiration")
    end
  end
end
