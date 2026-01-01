require 'rails_helper'

RSpec.describe GoalForm, type: :form do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:creator_teammate) { create(:teammate, person: person, organization: company) }
  let(:goal) { build(:goal, creator: creator_teammate, owner: creator_teammate) }
  let(:form) { GoalForm.new(goal) }
  
  before do
    form.current_person = person
    form.current_teammate = creator_teammate
  end
  
  describe 'validations' do
    it 'requires title' do
      form.title = nil
      expect(form).not_to be_valid
      expect(form.errors[:title]).to include("can't be blank")
    end
    
    it 'requires goal_type' do
      form.goal_type = nil
      expect(form).not_to be_valid
      expect(form.errors[:goal_type]).to include("can't be blank")
    end
    
    it 'allows earliest_target_date to be nil (dates are optional)' do
      form.earliest_target_date = nil
      expect(form).to be_valid
      # Target dates are optional - they can be set via timeframe selection or explicitly
    end
    
    it 'allows latest_target_date to be nil (dates are optional)' do
      form.latest_target_date = nil
      expect(form).to be_valid
      # Target dates are optional - they can be set via timeframe selection or explicitly
    end
    
    it 'allows most_likely_target_date to be nil (dates are optional)' do
      form.most_likely_target_date = nil
      expect(form).to be_valid
      # Target dates are optional - they can be set via timeframe selection or explicitly
    end
    
    it 'requires privacy_level' do
      form.privacy_level = nil
      expect(form).not_to be_valid
      expect(form.errors[:privacy_level]).to include("can't be blank")
    end
    
    it 'validates date ordering: earliest <= most_likely <= latest' do
      form.earliest_target_date = Date.today + 3.months
      form.most_likely_target_date = Date.today + 1.month
      form.latest_target_date = Date.today + 2.months
      
      expect(form).not_to be_valid
      expect(form.errors[:base]).to include("earliest_target_date must be less than or equal to most_likely_target_date")
    end
    
    it 'validates most_likely_target_date <= latest_target_date' do
      form.earliest_target_date = Date.today + 1.month
      form.most_likely_target_date = Date.today + 3.months
      form.latest_target_date = Date.today + 2.months
      
      expect(form).not_to be_valid
      expect(form.errors[:base]).to include("most_likely_target_date must be less than or equal to latest_target_date")
    end
    
    it 'accepts valid date ordering' do
      form.title = "Test Goal"
      form.goal_type = "inspirational_objective"
      form.earliest_target_date = Date.today + 1.month
      form.most_likely_target_date = Date.today + 2.months
      form.latest_target_date = Date.today + 3.months
      form.privacy_level = "only_creator"
      form.owner_type = "CompanyTeammate"
      form.owner_id = creator_teammate.id
      
      expect(form).to be_valid
    end
    
    it 'validates goal_type inclusion' do
      form.goal_type = 'invalid_type'
      expect(form).not_to be_valid
      expect(form.errors[:goal_type]).to include('is not included in the list')
    end
    
    it 'validates privacy_level inclusion' do
      form.privacy_level = 'invalid_level'
      expect(form).not_to be_valid
      expect(form.errors[:privacy_level]).to include('is not included in the list')
    end
    
    context 'with CompanyTeammate owner' do
      before do
        form.owner_type = 'CompanyTeammate'
        form.owner_id = creator_teammate.id
      end
      
      it 'allows all privacy levels' do
        Goal.privacy_levels.keys.each do |level|
          form.title = "Test Goal"
          form.goal_type = "inspirational_objective"
          form.earliest_target_date = Date.today + 1.month
          form.most_likely_target_date = Date.today + 2.months
          form.latest_target_date = Date.today + 3.months
          form.privacy_level = level
          
          expect(form).to be_valid, "should allow privacy_level #{level} for CompanyTeammate owner"
        end
      end
    end
    
    context 'with Organization owner' do
      before do
        form.owner_type = 'Company'
        form.owner_id = company.id
      end
      
      it 'does not allow only_creator_and_owner for Organization owner' do
        form.title = "Test Goal"
        form.goal_type = "inspirational_objective"
        form.earliest_target_date = Date.today + 1.month
        form.most_likely_target_date = Date.today + 2.months
        form.latest_target_date = Date.today + 3.months
        form.privacy_level = 'only_creator_and_owner'
        
        expect(form).not_to be_valid
        expect(form.errors[:privacy_level]).to include('is not valid for Organization owner')
      end
      
      it 'allows only_creator for Organization owner' do
        form.title = "Test Goal"
        form.goal_type = "inspirational_objective"
        form.earliest_target_date = Date.today + 1.month
        form.most_likely_target_date = Date.today + 2.months
        form.latest_target_date = Date.today + 3.months
        form.privacy_level = 'only_creator'
        
        expect(form).to be_valid
      end
    end
  end
  
  describe 'save method' do
    it 'sets creator to current_teammate' do
      form.title = "Test Goal"
      form.goal_type = "inspirational_objective"
      form.earliest_target_date = Date.today + 1.month
      form.most_likely_target_date = Date.today + 2.months
      form.latest_target_date = Date.today + 3.months
      form.privacy_level = "only_creator"
      form.owner_type = "CompanyTeammate"
      form.owner_id = creator_teammate.id
      
      expect(form.save).to be true
      expect(goal.creator).to eq(creator_teammate)
      expect(goal.owner_type).to eq('CompanyTeammate')
    end
    
    it 'saves goal with all attributes' do
      form.title = "My Goal"
      form.description = "Goal description"
      form.goal_type = "quantitative_key_result"
      form.earliest_target_date = Date.today + 1.month
      form.most_likely_target_date = Date.today + 2.months
      form.latest_target_date = Date.today + 3.months
      form.privacy_level = "only_creator_and_owner"
      form.owner_type = "CompanyTeammate"
      form.owner_id = creator_teammate.id
      
      expect(form.save).to be true
      expect(goal.title).to eq("My Goal")
      expect(goal.description).to eq("Goal description")
      expect(goal.goal_type).to eq("quantitative_key_result")
      expect(goal.privacy_level).to eq("only_creator_and_owner")
      expect(goal.owner_type).to eq('CompanyTeammate')
    end
    
    it 'handles optional started_at' do
      form.title = "Test Goal"
      form.goal_type = "inspirational_objective"
      form.earliest_target_date = Date.today + 1.month
      form.most_likely_target_date = Date.today + 2.months
      form.latest_target_date = Date.today + 3.months
      form.privacy_level = "only_creator"
      form.owner_type = "CompanyTeammate"
      form.owner_id = creator_teammate.id
      form.started_at = 1.day.ago
      
      expect(form.save).to be true
      expect(goal.started_at).to be_within(1.second).of(1.day.ago)
      expect(goal.owner_type).to eq('CompanyTeammate')
    end
    
    it 'handles optional became_top_priority' do
      form.title = "Test Goal"
      form.goal_type = "inspirational_objective"
      form.earliest_target_date = Date.today + 1.month
      form.most_likely_target_date = Date.today + 2.months
      form.latest_target_date = Date.today + 3.months
      form.privacy_level = "only_creator"
      form.owner_type = "CompanyTeammate"
      form.owner_id = creator_teammate.id
      form.became_top_priority = Time.current
      
      expect(form.save).to be true
      expect(goal.became_top_priority).to be_within(1.second).of(Time.current)
      expect(goal.owner_type).to eq('CompanyTeammate')
    end
    
    it 'does not save if invalid' do
      form.title = nil
      form.goal_type = "inspirational_objective"
      
      expect(form.save).to be false
      expect(goal).not_to be_persisted
    end
  end
  
  describe 'current_person and current_teammate' do
    it 'stores and retrieves current_person' do
      form.current_person = person
      expect(form.current_person).to eq(person)
    end
    
    it 'stores and retrieves current_teammate' do
      form.current_teammate = creator_teammate
      expect(form.current_teammate).to eq(creator_teammate)
    end
  end
  
  describe 'owner_type normalization' do
    it 'rejects Teammate as invalid owner_type' do
      form.title = "Test Goal"
      form.goal_type = "inspirational_objective"
      form.earliest_target_date = Date.today + 1.month
      form.most_likely_target_date = Date.today + 2.months
      form.latest_target_date = Date.today + 3.months
      form.privacy_level = "only_creator"
      form.owner_type = "Teammate"
      form.owner_id = creator_teammate.id
      
      expect(form).not_to be_valid
      expect(form.errors[:owner_id]).to be_present
    end
    
    it 'rejects Teammate_123 format as invalid' do
      form.title = "Test Goal"
      form.goal_type = "inspirational_objective"
      form.earliest_target_date = Date.today + 1.month
      form.most_likely_target_date = Date.today + 2.months
      form.latest_target_date = Date.today + 3.months
      form.privacy_level = "only_creator"
      form.owner_id = "Teammate_#{creator_teammate.id}"
      
      expect(form).not_to be_valid
      expect(form.errors[:owner_id]).to be_present
    end
    
    it 'keeps CompanyTeammate_123 format as CompanyTeammate' do
      form.title = "Test Goal"
      form.goal_type = "inspirational_objective"
      form.earliest_target_date = Date.today + 1.month
      form.most_likely_target_date = Date.today + 2.months
      form.latest_target_date = Date.today + 3.months
      form.privacy_level = "only_creator"
      form.owner_id = "CompanyTeammate_#{creator_teammate.id}"
      
      expect(form.save).to be true
      expect(goal.owner_type).to eq('CompanyTeammate')
      expect(goal.reload.owner_type).to eq('CompanyTeammate')
    end
  end
end



