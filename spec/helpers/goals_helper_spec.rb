require 'rails_helper'

RSpec.describe GoalsHelper, type: :helper do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:creator_teammate) { create(:teammate, person: person, organization: company) }
  
  describe '#goal_category_label' do
    it 'returns "Vision" for vision goals' do
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate, goal_type: 'inspirational_objective', most_likely_target_date: nil)
      expect(helper.goal_category_label(goal)).to eq('Vision')
    end
    
    it 'returns "Objective" for objective goals' do
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate, goal_type: 'inspirational_objective', most_likely_target_date: Date.today + 90.days)
      expect(helper.goal_category_label(goal)).to eq('Objective')
    end
    
    it 'returns "Key Result" for key result goals' do
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate, goal_type: 'quantitative_key_result', most_likely_target_date: Date.today + 90.days)
      expect(helper.goal_category_label(goal)).to eq('Key Result')
    end
    
    it 'returns "Bad Key Result" for bad key result goals' do
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate, goal_type: 'quantitative_key_result', most_likely_target_date: nil)
      expect(helper.goal_category_label(goal)).to eq('Bad Key Result')
    end
    
    it 'falls back to goal_type.humanize for unknown categories' do
      goal = double(goal_category: :unknown)
      allow(goal).to receive(:goal_type).and_return('some_type')
      
      # humanize will return "Some type" not "Some Type"
      expect(helper.goal_category_label(goal)).to eq('Some type')
    end
  end
  
  describe '#goal_category_badge_class' do
    it 'returns "bg-info" for vision goals' do
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate, goal_type: 'inspirational_objective', most_likely_target_date: nil)
      expect(helper.goal_category_badge_class(goal)).to eq('bg-info')
    end
    
    it 'returns "bg-primary" for objective goals' do
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate, goal_type: 'inspirational_objective', most_likely_target_date: Date.today + 90.days)
      expect(helper.goal_category_badge_class(goal)).to eq('bg-primary')
    end
    
    it 'returns "bg-success" for key result goals' do
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate, goal_type: 'quantitative_key_result', most_likely_target_date: Date.today + 90.days)
      expect(helper.goal_category_badge_class(goal)).to eq('bg-success')
    end
    
    it 'returns "bg-danger" for bad key result goals' do
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate, goal_type: 'quantitative_key_result', most_likely_target_date: nil)
      expect(helper.goal_category_badge_class(goal)).to eq('bg-danger')
    end
    
    it 'returns "bg-secondary" for unknown categories' do
      goal = double(goal_category: :unknown)
      expect(helper.goal_category_badge_class(goal)).to eq('bg-secondary')
    end
  end
  
  describe '#goal_warning_class' do
    it 'returns "table-danger" for goals that should show warning' do
      vision_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, goal_type: 'inspirational_objective', most_likely_target_date: nil)
      expect(helper.goal_warning_class(vision_goal)).to eq('table-danger')
      
      objective_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, goal_type: 'inspirational_objective', most_likely_target_date: Date.today + 90.days)
      expect(helper.goal_warning_class(objective_goal)).to eq('table-danger')
      
      bad_key_result_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, goal_type: 'quantitative_key_result', most_likely_target_date: nil)
      expect(helper.goal_warning_class(bad_key_result_goal)).to eq('table-danger')
    end
    
    it 'returns empty string for goals that should not show warning' do
      goal2 = create(:goal, creator: creator_teammate, owner: creator_teammate)
      vision_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, goal_type: 'inspirational_objective', most_likely_target_date: nil)
      create(:goal_link, this_goal: vision_goal, that_goal: goal2, link_type: 'this_is_key_result_of_that')
      
      expect(helper.goal_warning_class(vision_goal)).to eq('')
      
      key_result_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, goal_type: 'quantitative_key_result', most_likely_target_date: Date.today + 90.days)
      expect(helper.goal_warning_class(key_result_goal)).to eq('')
    end
  end
end

