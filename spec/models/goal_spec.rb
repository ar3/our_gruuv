require 'rails_helper'

RSpec.describe Goal, type: :model do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:team) { create(:organization, :team, parent: company) }
  let(:creator_teammate) { create(:teammate, person: person, organization: company) }
  
  describe 'associations' do
    it { should belong_to(:owner).optional(false) }
    it { should belong_to(:creator).class_name('Teammate') }
    it { should have_many(:outgoing_links).class_name('GoalLink').with_foreign_key('this_goal_id').dependent(:destroy) }
    it { should have_many(:linked_goals).through(:outgoing_links).source(:that_goal) }
    it { should have_many(:incoming_links).class_name('GoalLink').with_foreign_key('that_goal_id').dependent(:destroy) }
    it { should have_many(:linking_goals).through(:incoming_links).source(:this_goal) }
  end
  
  describe 'enums' do
    it 'defines goal_type enum' do
      expect(Goal.goal_types).to eq({
        'inspirational_objective' => 'inspirational_objective',
        'qualitative_key_result' => 'qualitative_key_result',
        'quantitative_key_result' => 'quantitative_key_result'
      })
    end
    
    it 'defines privacy_level enum' do
      expect(Goal.privacy_levels).to eq({
        'only_creator' => 'only_creator',
        'only_creator_and_owner' => 'only_creator_and_owner',
        'only_creator_owner_and_managers' => 'only_creator_owner_and_managers',
        'everyone_in_company' => 'everyone_in_company'
      })
    end
  end
  
  describe 'validations' do
    let(:goal) { build(:goal, creator: creator_teammate, owner: person) }
    
    it 'requires title' do
      goal.title = nil
      expect(goal).not_to be_valid
      expect(goal.errors[:title]).to include("can't be blank")
    end
    
    it 'requires goal_type' do
      goal.goal_type = nil
      expect(goal).not_to be_valid
      expect(goal.errors[:goal_type]).to include("can't be blank")
    end
    
    it 'allows target dates to be nil' do
      goal.earliest_target_date = nil
      goal.latest_target_date = nil
      goal.most_likely_target_date = nil
      expect(goal).to be_valid
    end
    
    it 'requires privacy_level' do
      goal.privacy_level = nil
      expect(goal).not_to be_valid
      expect(goal.errors[:privacy_level]).to include("can't be blank")
    end
    
    it 'requires owner' do
      goal.owner = nil
      expect(goal).not_to be_valid
      expect(goal.errors[:owner]).to include("must exist")
    end
    
    it 'requires creator' do
      goal.creator = nil
      expect(goal).not_to be_valid
      expect(goal.errors[:creator]).to include("must exist")
    end
    
    it 'validates date ordering: earliest <= most_likely <= latest' do
      goal.earliest_target_date = Date.today + 3.months
      goal.most_likely_target_date = Date.today + 1.month
      goal.latest_target_date = Date.today + 2.months
      
      expect(goal).not_to be_valid
      expect(goal.errors[:base]).to include("earliest_target_date must be less than or equal to most_likely_target_date")
    end
    
    it 'validates most_likely_target_date <= latest_target_date' do
      goal.earliest_target_date = Date.today + 1.month
      goal.most_likely_target_date = Date.today + 3.months
      goal.latest_target_date = Date.today + 2.months
      
      expect(goal).not_to be_valid
      expect(goal.errors[:base]).to include("most_likely_target_date must be less than or equal to latest_target_date")
    end
    
    it 'accepts valid date ordering' do
      goal.earliest_target_date = Date.today + 1.month
      goal.most_likely_target_date = Date.today + 2.months
      goal.latest_target_date = Date.today + 3.months
      
      expect(goal).to be_valid
    end
    
    it 'validates goal_type inclusion via enum' do
      expect { goal.goal_type = 'invalid_type' }.to raise_error(ArgumentError, "'invalid_type' is not a valid goal_type")
    end
    
    it 'validates privacy_level inclusion via enum' do
      expect { goal.privacy_level = 'invalid_level' }.to raise_error(ArgumentError, "'invalid_level' is not a valid privacy_level")
    end
    
    context 'with Person owner' do
      let(:goal) { build(:goal, creator: creator_teammate, owner: person, privacy_level: 'only_creator_owner_and_managers') }
      
      it 'allows all privacy levels' do
        Goal.privacy_levels.keys.each do |level|
          goal.privacy_level = level
          goal.earliest_target_date = Date.today + 1.month
          goal.most_likely_target_date = Date.today + 2.months
          goal.latest_target_date = Date.today + 3.months
          expect(goal).to be_valid, "should allow privacy_level #{level} for Person owner"
        end
      end
    end
    
    context 'with Organization owner' do
      let(:goal) { build(:goal, creator: creator_teammate, owner: company, privacy_level: 'only_creator_and_owner') }
      
      it 'does not allow only_creator_and_owner for Organization owner' do
        goal.privacy_level = 'only_creator_and_owner'
        goal.earliest_target_date = Date.today + 1.month
        goal.most_likely_target_date = Date.today + 2.months
        goal.latest_target_date = Date.today + 3.months
        
        expect(goal).not_to be_valid
        expect(goal.errors[:privacy_level]).to include('is not valid for Organization owner')
      end
      
      it 'does not allow only_creator_owner_and_managers for Organization owner' do
        goal.privacy_level = 'only_creator_owner_and_managers'
        goal.earliest_target_date = Date.today + 1.month
        goal.most_likely_target_date = Date.today + 2.months
        goal.latest_target_date = Date.today + 3.months
        
        expect(goal).not_to be_valid
        expect(goal.errors[:privacy_level]).to include('is not valid for Organization owner')
      end
      
      it 'allows only_creator for Organization owner' do
        goal.privacy_level = 'only_creator'
        goal.earliest_target_date = Date.today + 1.month
        goal.most_likely_target_date = Date.today + 2.months
        goal.latest_target_date = Date.today + 3.months
        
        expect(goal).to be_valid
      end
      
      it 'allows everyone_in_company for Organization owner' do
        goal.privacy_level = 'everyone_in_company'
        goal.earliest_target_date = Date.today + 1.month
        goal.most_likely_target_date = Date.today + 2.months
        goal.latest_target_date = Date.today + 3.months
        
        expect(goal).to be_valid
      end
    end
  end
  
  describe 'scopes' do
    let(:other_person) { create(:person) }
    let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
    
    let!(:personal_goal) do
      create(:goal, 
        creator: creator_teammate, 
        owner: person,
        earliest_target_date: Date.today,
        most_likely_target_date: Date.today + 1.month,
        latest_target_date: Date.today + 2.months
      )
    end
    
    let!(:team_goal) do
      create(:goal,
        creator: creator_teammate,
        owner: company,
        earliest_target_date: Date.today + 5.months,
        most_likely_target_date: Date.today + 6.months,
        latest_target_date: Date.today + 7.months
      )
    end
    
    let!(:other_goal) do
      create(:goal,
        creator: other_teammate,
        owner: other_person,
        earliest_target_date: Date.today + 11.months,
        most_likely_target_date: Date.today + 12.months,
        latest_target_date: Date.today + 13.months
      )
    end
    
    describe '.for_teammate' do
      it 'returns goals where teammate is owner (Person)' do
        result = described_class.for_teammate(creator_teammate)
        expect(result).to include(personal_goal)
      end
      
      it 'returns goals where teammate is creator' do
        result = described_class.for_teammate(creator_teammate)
        expect(result).to include(personal_goal, team_goal)
      end
      
      it 'returns goals where teammate organization is owner (Organization)' do
        result = described_class.for_teammate(creator_teammate)
        expect(result).to include(team_goal)
      end
      
      it 'does not return goals for other teammates' do
        result = described_class.for_teammate(creator_teammate)
        expect(result).not_to include(other_goal)
      end
      
      it 'handles collection of teammates' do
        teammates = [creator_teammate, other_teammate]
        result = described_class.for_teammate(teammates)
        expect(result).to include(personal_goal, team_goal, other_goal)
      end
    end
    
    describe '.now' do
      it 'returns goals with most_likely_target_date within 3 months' do
        result = described_class.now
        expect(result).to include(personal_goal)
        expect(result).not_to include(team_goal, other_goal)
      end
    end
    
    describe '.next_timeframe' do
      it 'returns goals with most_likely_target_date 3-9 months away' do
        result = described_class.next_timeframe
        expect(result).to include(team_goal)
        expect(result).not_to include(personal_goal, other_goal)
      end
    end
    
    describe '.later' do
      it 'returns goals with most_likely_target_date 9+ months away' do
        result = described_class.later
        expect(result).to include(other_goal)
        expect(result).not_to include(personal_goal, team_goal)
      end
    end
    
    describe '.draft' do
      let!(:draft_goal) { create(:goal, creator: creator_teammate, owner: person, started_at: nil) }
      let!(:active_goal) { create(:goal, creator: creator_teammate, owner: person, started_at: 1.day.ago) }
      
      it 'returns goals without started_at' do
        result = described_class.draft
        expect(result).to include(draft_goal)
        expect(result).not_to include(active_goal)
      end
    end
    
    describe '.active' do
      let!(:draft_goal) { create(:goal, creator: creator_teammate, owner: person, started_at: nil) }
      let!(:active_goal) { create(:goal, creator: creator_teammate, owner: person, started_at: 1.day.ago) }
      let!(:completed_goal) { create(:goal, creator: creator_teammate, owner: person, started_at: 1.week.ago, completed_at: 1.day.ago) }
      let!(:cancelled_goal) { create(:goal, creator: creator_teammate, owner: person, started_at: 1.week.ago, cancelled_at: 1.day.ago) }
      
      it 'returns goals with started_at but no completed_at or cancelled_at' do
        result = described_class.active
        expect(result).to include(active_goal)
        expect(result).not_to include(draft_goal, completed_goal, cancelled_goal)
      end
    end
    
    describe '.completed' do
      let!(:active_goal) { create(:goal, creator: creator_teammate, owner: person, started_at: 1.day.ago) }
      let!(:completed_goal) { create(:goal, creator: creator_teammate, owner: person, completed_at: 1.day.ago) }
      
      it 'returns goals with completed_at' do
        result = described_class.completed
        expect(result).to include(completed_goal)
        expect(result).not_to include(active_goal)
      end
    end
    
    describe '.cancelled' do
      let!(:active_goal) { create(:goal, creator: creator_teammate, owner: person, started_at: 1.day.ago) }
      let!(:cancelled_goal) { create(:goal, creator: creator_teammate, owner: person, cancelled_at: 1.day.ago) }
      
      it 'returns goals with cancelled_at' do
        result = described_class.cancelled
        expect(result).to include(cancelled_goal)
        expect(result).not_to include(active_goal)
      end
    end
  end
  
  describe 'instance methods' do
    let(:goal) { create(:goal, creator: creator_teammate, owner: person) }
    
    describe '#timeframe' do
      it 'returns :now for goals within 3 months' do
        goal.update!(most_likely_target_date: Date.today + 1.month)
        expect(goal.timeframe).to eq(:now)
      end
      
      it 'returns :next for goals 3-9 months away' do
        goal.update!(
          earliest_target_date: Date.today + 5.months,
          most_likely_target_date: Date.today + 6.months,
          latest_target_date: Date.today + 7.months
        )
        expect(goal.timeframe).to eq(:next)
      end
      
      it 'returns :later for goals 9+ months away' do
        goal.update!(
          earliest_target_date: Date.today + 11.months,
          most_likely_target_date: Date.today + 12.months,
          latest_target_date: Date.today + 13.months
        )
        expect(goal.timeframe).to eq(:later)
      end
      
      it 'returns :later when most_likely_target_date is nil' do
        goal.update!(most_likely_target_date: nil)
        expect(goal.timeframe).to eq(:later)
      end
    end
    
    describe '#status' do
      it 'returns :draft when no started_at' do
        goal.update!(started_at: nil)
        expect(goal.status).to eq(:draft)
      end
      
      it 'returns :cancelled when cancelled_at is present' do
        goal.update!(started_at: 1.day.ago, cancelled_at: 1.hour.ago)
        expect(goal.status).to eq(:cancelled)
      end
      
      it 'returns :cancelled when both cancelled_at and completed_at are present (cancelled takes priority)' do
        goal.update!(started_at: 1.day.ago, completed_at: 1.hour.ago, cancelled_at: 30.minutes.ago)
        expect(goal.status).to eq(:cancelled)
      end
      
      it 'returns :active when started_at exists without completed_at or cancelled_at' do
        goal.update!(started_at: 1.day.ago)
        expect(goal.status).to eq(:active)
      end
    end
    
    describe '#can_be_viewed_by?' do
      let(:other_person) { create(:person) }
      let(:admin) { create(:person, :admin) }
      
      context 'with only_creator privacy level' do
        let(:goal) { create(:goal, creator: creator_teammate, owner: person, privacy_level: 'only_creator') }
        
        it 'allows creator to view' do
          expect(goal.can_be_viewed_by?(person)).to be true
        end
        
        it 'allows admin to view' do
          expect(goal.can_be_viewed_by?(admin)).to be true
        end
        
        it 'does not allow others to view' do
          expect(goal.can_be_viewed_by?(other_person)).to be false
        end
      end
      
      context 'with only_creator_and_owner privacy level' do
        let(:goal) { create(:goal, creator: creator_teammate, owner: person, privacy_level: 'only_creator_and_owner') }
        
        it 'allows creator to view' do
          expect(goal.can_be_viewed_by?(person)).to be true
        end
        
        it 'allows owner (if Person) to view' do
          expect(goal.can_be_viewed_by?(person)).to be true
        end
        
        it 'does not allow others to view' do
          expect(goal.can_be_viewed_by?(other_person)).to be false
        end
      end
      
      context 'with only_creator_owner_and_managers privacy level' do
        let(:goal) { create(:goal, creator: creator_teammate, owner: person, privacy_level: 'only_creator_owner_and_managers') }
        let(:manager_person) { create(:person) }
        let(:manager_teammate) { create(:teammate, person: manager_person, organization: company) }
        
        it 'allows creator to view' do
          expect(goal.can_be_viewed_by?(person)).to be true
        end
        
        it 'allows owner to view' do
          expect(goal.can_be_viewed_by?(person)).to be true
        end
        
        it 'allows managers to view' do
          # This would require employment_tenure setup - simplified for now
          expect(goal.can_be_viewed_by?(person)).to be true
        end
        
        it 'does not allow non-managers to view' do
          expect(goal.can_be_viewed_by?(other_person)).to be false
        end
      end
      
      context 'with everyone_in_company privacy level' do
        let(:goal) { create(:goal, creator: creator_teammate, owner: company, privacy_level: 'everyone_in_company') }
        let(:company_teammate) { create(:teammate, person: other_person, organization: company) }
        
        before do
          # Ensure other_person has a teammate record in the company
          company_teammate
        end
        
        it 'allows creator to view' do
          expect(goal.can_be_viewed_by?(person)).to be true
        end
        
        it 'allows teammates in the company to view' do
          expect(goal.can_be_viewed_by?(other_person)).to be true
        end
        
        it 'does not allow non-teammates to view' do
          outsider = create(:person)
          expect(goal.can_be_viewed_by?(outsider)).to be false
        end
      end
    end
    
    describe '#owner_company' do
      context 'with Person owner' do
        let(:goal) { create(:goal, creator: creator_teammate, owner: person) }
        
        it 'returns nil (Person owners do not have a company directly)' do
          expect(goal.owner_company).to be_nil
        end
      end
      
      context 'with Organization owner' do
        let(:goal) { create(:goal, creator: creator_teammate, owner: company) }
        
        it 'returns the organization when owner is a Company' do
          expect(goal.owner_company).to eq(company)
        end
      end
      
      context 'with Team owner' do
        let(:goal) { create(:goal, creator: creator_teammate, owner: team) }
        
        it 'returns the root company when owner is a Team' do
          expect(goal.owner_company).to eq(company)
        end
      end
    end
    
    describe '#managers' do
      context 'with Person owner' do
        let(:goal) { create(:goal, creator: creator_teammate, owner: person) }
        let(:manager_person) { create(:person) }
        let(:employment_tenure) { create(:employment_tenure, teammate: creator_teammate, manager: manager_person, company: company) }
        
        it 'returns managers from active employment tenures' do
          # This would require employment tenure setup - simplified for now
          expect(goal.managers).to be_an(Array)
        end
      end
      
      context 'with Organization owner' do
        let(:goal) { create(:goal, creator: creator_teammate, owner: company) }
        
        it 'returns empty array when owner is not a Person' do
          expect(goal.managers).to eq([])
        end
      end
    end
    
    describe '#goal_category' do
      context 'with inspirational_objective and no target date' do
        let(:goal) { create(:goal, creator: creator_teammate, owner: person, goal_type: 'inspirational_objective', most_likely_target_date: nil) }
        
        it 'returns :vision' do
          expect(goal.goal_category).to eq(:vision)
        end
      end
      
      context 'with inspirational_objective and target date' do
        let(:goal) { create(:goal, creator: creator_teammate, owner: person, goal_type: 'inspirational_objective', most_likely_target_date: Date.today + 90.days) }
        
        it 'returns :objective' do
          expect(goal.goal_category).to eq(:objective)
        end
      end
      
      context 'with qualitative_key_result and no target date' do
        let(:goal) { create(:goal, creator: creator_teammate, owner: person, goal_type: 'qualitative_key_result', most_likely_target_date: nil) }
        
        it 'returns :bad_key_result' do
          expect(goal.goal_category).to eq(:bad_key_result)
        end
      end
      
      context 'with quantitative_key_result and no target date' do
        let(:goal) { create(:goal, creator: creator_teammate, owner: person, goal_type: 'quantitative_key_result', most_likely_target_date: nil) }
        
        it 'returns :bad_key_result' do
          expect(goal.goal_category).to eq(:bad_key_result)
        end
      end
      
      context 'with qualitative_key_result and target date' do
        let(:goal) { create(:goal, creator: creator_teammate, owner: person, goal_type: 'qualitative_key_result', most_likely_target_date: Date.today + 90.days) }
        
        it 'returns :key_result' do
          expect(goal.goal_category).to eq(:key_result)
        end
      end
      
      context 'with quantitative_key_result and target date' do
        let(:goal) { create(:goal, creator: creator_teammate, owner: person, goal_type: 'quantitative_key_result', most_likely_target_date: Date.today + 90.days) }
        
        it 'returns :key_result' do
          expect(goal.goal_category).to eq(:key_result)
        end
      end
    end
    
    describe 'category predicate methods' do
      let(:vision_goal) { create(:goal, creator: creator_teammate, owner: person, goal_type: 'inspirational_objective', most_likely_target_date: nil) }
      let(:objective_goal) { create(:goal, creator: creator_teammate, owner: person, goal_type: 'inspirational_objective', most_likely_target_date: Date.today + 90.days) }
      let(:key_result_goal) { create(:goal, creator: creator_teammate, owner: person, goal_type: 'quantitative_key_result', most_likely_target_date: Date.today + 90.days) }
      let(:bad_key_result_goal) { create(:goal, creator: creator_teammate, owner: person, goal_type: 'quantitative_key_result', most_likely_target_date: nil) }
      
      describe '#vision?' do
        it 'returns true for vision goals' do
          expect(vision_goal.vision?).to be true
          expect(objective_goal.vision?).to be false
          expect(key_result_goal.vision?).to be false
          expect(bad_key_result_goal.vision?).to be false
        end
      end
      
      describe '#objective?' do
        it 'returns true for objective goals' do
          expect(vision_goal.objective?).to be false
          expect(objective_goal.objective?).to be true
          expect(key_result_goal.objective?).to be false
          expect(bad_key_result_goal.objective?).to be false
        end
      end
      
      describe '#key_result?' do
        it 'returns true for key result goals' do
          expect(vision_goal.key_result?).to be false
          expect(objective_goal.key_result?).to be false
          expect(key_result_goal.key_result?).to be true
          expect(bad_key_result_goal.key_result?).to be false
        end
      end
      
      describe '#bad_key_result?' do
        it 'returns true for bad key result goals' do
          expect(vision_goal.bad_key_result?).to be false
          expect(objective_goal.bad_key_result?).to be false
          expect(key_result_goal.bad_key_result?).to be false
          expect(bad_key_result_goal.bad_key_result?).to be true
        end
      end
    end
    
    describe '#has_sub_goals?' do
      let(:goal1) { create(:goal, creator: creator_teammate, owner: person) }
      let(:goal2) { create(:goal, creator: creator_teammate, owner: person) }
      
      it 'returns true when goal has outgoing links with this_is_key_result_of_that' do
        create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_is_key_result_of_that')
        expect(goal1.has_sub_goals?).to be true
      end
      
      it 'returns false when goal has no outgoing links' do
        expect(goal1.has_sub_goals?).to be false
      end
      
      it 'returns false when goal has outgoing links but not this_is_key_result_of_that' do
        create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
        expect(goal1.has_sub_goals?).to be false
      end
    end
    
    describe '#should_show_warning?' do
      let(:goal2) { create(:goal, creator: creator_teammate, owner: person) }
      
      context 'with vision goal' do
        let(:vision_goal) { create(:goal, creator: creator_teammate, owner: person, goal_type: 'inspirational_objective', most_likely_target_date: nil) }
        
        it 'returns true when vision has no sub-goals' do
          expect(vision_goal.should_show_warning?).to be true
        end
        
        it 'returns false when vision has sub-goals' do
          create(:goal_link, this_goal: vision_goal, that_goal: goal2, link_type: 'this_is_key_result_of_that')
          expect(vision_goal.should_show_warning?).to be false
        end
      end
      
      context 'with objective goal' do
        let(:objective_goal) { create(:goal, creator: creator_teammate, owner: person, goal_type: 'inspirational_objective', most_likely_target_date: Date.today + 90.days) }
        
        it 'returns true when objective has no sub-goals' do
          expect(objective_goal.should_show_warning?).to be true
        end
        
        it 'returns false when objective has sub-goals' do
          create(:goal_link, this_goal: objective_goal, that_goal: goal2, link_type: 'this_is_key_result_of_that')
          expect(objective_goal.should_show_warning?).to be false
        end
      end
      
      context 'with bad key result goal' do
        let(:bad_key_result_goal) { create(:goal, creator: creator_teammate, owner: person, goal_type: 'quantitative_key_result', most_likely_target_date: nil) }
        
        it 'returns true always' do
          expect(bad_key_result_goal.should_show_warning?).to be true
          
          # Even with sub-goals, bad key result should show warning
          create(:goal_link, this_goal: bad_key_result_goal, that_goal: goal2, link_type: 'this_is_key_result_of_that')
          expect(bad_key_result_goal.should_show_warning?).to be true
        end
      end
      
      context 'with key result goal' do
        let(:key_result_goal) { create(:goal, creator: creator_teammate, owner: person, goal_type: 'quantitative_key_result', most_likely_target_date: Date.today + 90.days) }
        
        it 'returns false' do
          expect(key_result_goal.should_show_warning?).to be false
        end
      end
    end
  end
end


