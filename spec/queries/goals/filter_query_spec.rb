require 'rails_helper'

RSpec.describe Goals::FilterQuery do
  let(:organization) { create(:organization) }
  let(:creator) { create(:teammate, organization: organization) }
  
  let!(:active_goal) { create(:goal, creator: creator, owner: creator) }
  let!(:deleted_goal) { create(:goal, creator: creator, owner: creator, deleted_at: 1.day.ago) }
  let!(:completed_goal) { create(:goal, creator: creator, owner: creator, completed_at: 1.day.ago) }
  let!(:deleted_and_completed_goal) { create(:goal, creator: creator, owner: creator, deleted_at: 1.day.ago, completed_at: 1.day.ago) }
  
  describe '#call' do
    it 'excludes deleted and completed by default' do
      result = described_class.new.call
      expect(result).to contain_exactly(active_goal)
    end
    
    it 'includes deleted when show_deleted is true' do
      result = described_class.new.call(show_deleted: true)
      expect(result).to contain_exactly(active_goal, deleted_goal, deleted_and_completed_goal)
    end
    
    it 'includes completed when show_completed is true' do
      result = described_class.new.call(show_completed: true)
      expect(result).to contain_exactly(active_goal, completed_goal, deleted_and_completed_goal)
    end
    
    it 'includes all goals when both are true' do
      result = described_class.new.call(show_deleted: true, show_completed: true)
      expect(result).to contain_exactly(active_goal, deleted_goal, completed_goal, deleted_and_completed_goal)
    end
    
    it 'works with a scoped relation' do
      other_creator = create(:teammate, organization: organization)
      other_goal = create(:goal, creator: other_creator, owner: other_creator)
      
      scoped_relation = Goal.where(creator: creator)
      result = described_class.new(scoped_relation).call
      
      expect(result).to contain_exactly(active_goal)
      expect(result).not_to include(other_goal)
    end
  end
end

