require 'rails_helper'

RSpec.describe Goals::BulkUpdateCheckInsService, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:week_start) { Date.current.beginning_of_week(:monday) }
  
  let(:goal) do
    create(:goal,
      creator: teammate,
      owner: teammate,
      company: organization,
      started_at: 1.week.ago,
      most_likely_target_date: Date.today + 1.month
    )
  end

  describe '#call' do
    context 'when both confidence and reason are provided' do
      it 'creates a new check-in' do
        params = {
          goal.id => {
            confidence_percentage: '75',
            confidence_reason: 'Making good progress'
          }
        }
        
        result = described_class.call(
          organization: organization,
          current_person: person,
          goal_check_ins_params: params,
          week_start: week_start
        )
        
        expect(result.ok?).to be true
        expect(result.value[:success_count]).to eq(1)
        expect(result.value[:failure_count]).to eq(0)
        
        check_in = GoalCheckIn.find_by(goal: goal, check_in_week_start: week_start)
        expect(check_in).to be_present
        expect(check_in.confidence_percentage).to eq(75)
        expect(check_in.confidence_reason).to eq('Making good progress')
        expect(check_in.confidence_reporter).to eq(person)
      end
      
      it 'updates an existing check-in' do
        existing_check_in = create(:goal_check_in,
          goal: goal,
          check_in_week_start: week_start,
          confidence_percentage: 50,
          confidence_reason: 'Old reason',
          confidence_reporter: person
        )
        
        params = {
          goal.id => {
            confidence_percentage: '80',
            confidence_reason: 'New reason'
          }
        }
        
        result = described_class.call(
          organization: organization,
          current_person: person,
          goal_check_ins_params: params,
          week_start: week_start
        )
        
        expect(result.ok?).to be true
        expect(result.value[:success_count]).to eq(1)
        
        existing_check_in.reload
        expect(existing_check_in.confidence_percentage).to eq(80)
        expect(existing_check_in.confidence_reason).to eq('New reason')
      end
    end
    
    context 'when only confidence is provided' do
      it 'creates a check-in with only confidence' do
        params = {
          goal.id => {
            confidence_percentage: '65'
          }
        }
        
        result = described_class.call(
          organization: organization,
          current_person: person,
          goal_check_ins_params: params,
          week_start: week_start
        )
        
        expect(result.ok?).to be true
        expect(result.value[:success_count]).to eq(1)
        
        check_in = GoalCheckIn.find_by(goal: goal, check_in_week_start: week_start)
        expect(check_in).to be_present
        expect(check_in.confidence_percentage).to eq(65)
        expect(check_in.confidence_reason).to be_nil
      end
    end
    
    context 'when only reason is provided' do
      context 'when there is a previous check-in' do
        it 'uses the last check-in confidence' do
          previous_check_in = create(:goal_check_in,
            goal: goal,
            check_in_week_start: week_start - 1.week,
            confidence_percentage: 70,
            confidence_reason: 'Previous reason',
            confidence_reporter: person
          )
          
          params = {
            goal.id => {
              confidence_reason: 'New reason only'
            }
          }
          
          result = described_class.call(
            organization: organization,
            current_person: person,
            goal_check_ins_params: params,
            week_start: week_start
          )
          
          expect(result.ok?).to be true
          expect(result.value[:success_count]).to eq(1)
          
          check_in = GoalCheckIn.find_by(goal: goal, check_in_week_start: week_start)
          expect(check_in).to be_present
          expect(check_in.confidence_percentage).to eq(70) # Uses previous confidence
          expect(check_in.confidence_reason).to eq('New reason only')
        end
      end
      
      context 'when there is no previous check-in' do
        it 'defaults confidence to 5%' do
          params = {
            goal.id => {
              confidence_reason: 'Reason only, no previous check-in'
            }
          }
          
          result = described_class.call(
            organization: organization,
            current_person: person,
            goal_check_ins_params: params,
            week_start: week_start
          )
          
          expect(result.ok?).to be true
          expect(result.value[:success_count]).to eq(1)
          
          check_in = GoalCheckIn.find_by(goal: goal, check_in_week_start: week_start)
          expect(check_in).to be_present
          expect(check_in.confidence_percentage).to eq(5) # Defaults to 5%
          expect(check_in.confidence_reason).to eq('Reason only, no previous check-in')
        end
      end
    end
    
    context 'when both fields are empty' do
      context 'when check-in exists' do
        it 'deletes the existing check-in' do
          existing_check_in = create(:goal_check_in,
            goal: goal,
            check_in_week_start: week_start,
            confidence_percentage: 50,
            confidence_reason: 'Some reason',
            confidence_reporter: person
          )
          
          params = {
            goal.id => {
              confidence_percentage: '',
              confidence_reason: ''
            }
          }
          
          result = described_class.call(
            organization: organization,
            current_person: person,
            goal_check_ins_params: params,
            week_start: week_start
          )
          
          expect(result.ok?).to be true
          expect(result.value[:success_count]).to eq(1)
          
          expect(GoalCheckIn.find_by(id: existing_check_in.id)).to be_nil
        end
      end
      
      context 'when check-in does not exist' do
        it 'does nothing and succeeds' do
          params = {
            goal.id => {
              confidence_percentage: '',
              confidence_reason: ''
            }
          }
          
          result = described_class.call(
            organization: organization,
            current_person: person,
            goal_check_ins_params: params,
            week_start: week_start
          )
          
          expect(result.ok?).to be true
          expect(result.value[:success_count]).to eq(0)
          expect(result.value[:failure_count]).to eq(0)
          
          expect(GoalCheckIn.find_by(goal: goal, check_in_week_start: week_start)).to be_nil
        end
      end
    end
    
    context 'when updating multiple goals' do
      let(:goal2) do
        create(:goal,
          creator: teammate,
          owner: teammate,
          company: organization,
          started_at: 1.week.ago,
          most_likely_target_date: Date.today + 2.months
        )
      end
      
      it 'processes all goals independently' do
        params = {
          goal.id => {
            confidence_percentage: '75',
            confidence_reason: 'Goal 1 reason'
          },
          goal2.id => {
            confidence_percentage: '80',
            confidence_reason: 'Goal 2 reason'
          }
        }
        
        result = described_class.call(
          organization: organization,
          current_person: person,
          goal_check_ins_params: params,
          week_start: week_start
        )
        
        expect(result.ok?).to be true
        expect(result.value[:success_count]).to eq(2)
        
        check_in1 = GoalCheckIn.find_by(goal: goal, check_in_week_start: week_start)
        check_in2 = GoalCheckIn.find_by(goal: goal2, check_in_week_start: week_start)
        
        expect(check_in1.confidence_percentage).to eq(75)
        expect(check_in1.confidence_reason).to eq('Goal 1 reason')
        expect(check_in2.confidence_percentage).to eq(80)
        expect(check_in2.confidence_reason).to eq('Goal 2 reason')
      end
    end
    
    context 'when goal is completed' do
      it 'skips the check-in update' do
        goal.update!(completed_at: 1.day.ago)
        
        params = {
          goal.id => {
            confidence_percentage: '75',
            confidence_reason: 'Should not save'
          }
        }
        
        result = described_class.call(
          organization: organization,
          current_person: person,
          goal_check_ins_params: params,
          week_start: week_start
        )
        
        expect(result.ok?).to be true
        expect(result.value[:success_count]).to eq(0)
        
        expect(GoalCheckIn.find_by(goal: goal, check_in_week_start: week_start)).to be_nil
      end
    end
    
    context 'when user lacks permission' do
      let(:other_person) { create(:person) }
      let(:private_goal) do
        create(:goal,
          creator: teammate,
          owner: teammate,
          company: organization,
          started_at: 1.week.ago,
          privacy_level: 'only_creator'
        )
      end
      
      it 'returns an error for unauthorized goals' do
        params = {
          private_goal.id => {
            confidence_percentage: '75',
            confidence_reason: 'Should not save'
          }
        }
        
        result = described_class.call(
          organization: organization,
          current_person: other_person,
          goal_check_ins_params: params,
          week_start: week_start
        )
        
        expect(result.ok?).to be true
        expect(result.value[:failure_count]).to eq(1)
        expect(result.value[:errors].first[:message]).to include('permission')
      end
    end
    
    context 'when goal auto-completes' do
      it 'auto-completes goal when confidence is 0%' do
        params = {
          goal.id => {
            confidence_percentage: '0',
            confidence_reason: 'Not happening'
          }
        }
        
        result = described_class.call(
          organization: organization,
          current_person: person,
          goal_check_ins_params: params,
          week_start: week_start
        )
        
        expect(result.ok?).to be true
        expect(goal.reload.completed_at).to be_present
      end
      
      it 'auto-completes goal when confidence is 100%' do
        params = {
          goal.id => {
            confidence_percentage: '100',
            confidence_reason: 'Done!'
          }
        }
        
        result = described_class.call(
          organization: organization,
          current_person: person,
          goal_check_ins_params: params,
          week_start: week_start
        )
        
        expect(result.ok?).to be true
        expect(goal.reload.completed_at).to be_present
      end
    end
  end
end

