require 'rails_helper'

RSpec.describe Goals::BulkCreateService, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:linking_goal) { create(:goal, creator: teammate, owner: person, privacy_level: 'everyone_in_company') }
  let(:goal_titles) { ['Goal 1', 'Goal 2', 'Goal 3'] }
  let(:link_type) { 'this_is_key_result_of_that' }
  
  describe '#initialize' do
    it 'sets instance variables correctly' do
      service = described_class.new(
        organization, person, teammate, linking_goal, :outgoing, goal_titles, link_type
      )
      
      expect(service.organization).to eq(organization)
      expect(service.current_person).to eq(person)
      expect(service.current_teammate).to eq(teammate)
      expect(service.linking_goal).to eq(linking_goal)
      expect(service.link_direction).to eq(:outgoing)
      expect(service.goal_titles).to eq(goal_titles)
      expect(service.link_type).to eq(link_type)
    end
    
    it 'rejects blank titles' do
      titles = ['Goal 1', '', '  ', 'Goal 2']
      service = described_class.new(
        organization, person, teammate, linking_goal, :outgoing, titles, link_type
      )
      
      expect(service.goal_titles).to eq(['Goal 1', 'Goal 2'])
    end
  end
  
  describe '#call' do
    context 'with outgoing links' do
      it 'creates goals as quantitative_key_result' do
        service = described_class.new(
          organization, person, teammate, linking_goal, :outgoing, goal_titles, link_type
        )
        
        expect { service.call }.to change { Goal.count }.by(3)
        
        created_goals = Goal.last(3)
        created_goals.each do |goal|
          expect(goal.goal_type).to eq('quantitative_key_result')
          expect(goal.most_likely_target_date).to be_nil
          expect(goal.owner).to eq(linking_goal.owner)
          expect(goal.privacy_level).to eq(linking_goal.privacy_level)
          expect(goal.creator).to eq(teammate)
        end
        
        expect(service.created_goals).to eq(created_goals)
        expect(service.errors).to be_empty
      end
      
      it 'creates links from linking_goal to created goals' do
        service = described_class.new(
          organization, person, teammate, linking_goal, :outgoing, goal_titles, link_type
        )
        
        expect { service.call }.to change { GoalLink.count }.by(3)
        
        created_goals = Goal.last(3)
        created_goals.each do |goal|
          link = GoalLink.find_by(this_goal: linking_goal, that_goal: goal, link_type: link_type)
          expect(link).to be_present
        end
      end
      
      it 'sets title and description to the same value' do
        service = described_class.new(
          organization, person, teammate, linking_goal, :outgoing, goal_titles, link_type
        )
        
        service.call
        
        created_goals = Goal.last(3)
        created_goals.each_with_index do |goal, index|
          expect(goal.title).to eq(goal_titles[index])
          expect(goal.description).to eq(goal_titles[index])
        end
      end
    end
    
    context 'with incoming links' do
      it 'creates goals as inspirational_objective' do
        service = described_class.new(
          organization, person, teammate, linking_goal, :incoming, goal_titles, link_type
        )
        
        expect { service.call }.to change { Goal.count }.by(3)
        
        created_goals = Goal.last(3)
        created_goals.each do |goal|
          expect(goal.goal_type).to eq('inspirational_objective')
          expect(goal.most_likely_target_date).to be_nil
          expect(goal.owner).to eq(linking_goal.owner)
          expect(goal.privacy_level).to eq(linking_goal.privacy_level)
        end
      end
      
      it 'creates links from created goals to linking_goal' do
        service = described_class.new(
          organization, person, teammate, linking_goal, :incoming, goal_titles, link_type
        )
        
        expect { service.call }.to change { GoalLink.count }.by(3)
        
        created_goals = Goal.last(3)
        created_goals.each do |goal|
          link = GoalLink.find_by(this_goal: goal, that_goal: linking_goal, link_type: link_type)
          expect(link).to be_present
        end
      end
    end
    
    context 'with empty titles' do
      it 'returns false and does not create any goals' do
        service = described_class.new(
          organization, person, teammate, linking_goal, :outgoing, [], link_type
        )
        
        expect { service.call }.not_to change { Goal.count }
        expect(service.call).to be false
      end
    end
    
    context 'with invalid goal data' do
      it 'returns false and collects errors' do
        # Create a goal with invalid data by stubbing save to return false
        service = described_class.new(
          organization, person, teammate, linking_goal, :outgoing, ['Goal 1'], link_type
        )
        
        allow_any_instance_of(Goal).to receive(:save).and_return(false)
        allow_any_instance_of(Goal).to receive(:errors).and_return(
          double(full_messages: ["Title can't be blank"])
        )
        
        expect { service.call }.not_to change { Goal.count }
        expect(service.call).to be false
        expect(service.errors).not_to be_empty
      end
    end
    
    context 'transaction rollback' do
      it 'rolls back all changes if any goal creation fails' do
        service = described_class.new(
          organization, person, teammate, linking_goal, :outgoing, goal_titles, link_type
        )
        
        # Make the second goal creation fail by stubbing save to return false for one goal
        allow_any_instance_of(Goal).to receive(:save).and_return(true)
        call_count = 0
        allow_any_instance_of(Goal).to receive(:save) do |goal|
          call_count += 1
          if call_count == 2
            goal.errors.add(:base, 'Simulated error')
            false
          else
            goal.update_column(:created_at, Time.current) if goal.persisted?
            true
          end
        end
        
        initial_count = Goal.count
        expect(service.call).to be false
        expect(Goal.count).to eq(initial_count)
      end
    end
  end
end

