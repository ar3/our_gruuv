require 'rails_helper'

RSpec.describe GoalsHelper, type: :helper do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:creator_teammate) { create(:company_teammate, person: person, organization: company) }
  
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
      create(:goal_link, parent: vision_goal, child: goal2)
      
      expect(helper.goal_warning_class(vision_goal)).to eq('')
      
      key_result_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, goal_type: 'quantitative_key_result', most_likely_target_date: Date.today + 90.days)
      expect(helper.goal_warning_class(key_result_goal)).to eq('')
    end
  end
  
  describe '#goal_owner_display_name' do
    it 'returns person display name for CompanyTeammate owner' do
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate)
      expect(helper.goal_owner_display_name(goal)).to eq(person.display_name)
    end

    it 'returns organization display name for Organization owner' do
      goal = create(:goal, creator: creator_teammate, owner: company, privacy_level: 'everyone_in_company')
      expect(helper.goal_owner_display_name(goal)).to eq(company.display_name)
    end

    it 'returns "Unknown" when owner is nil' do
      goal = build(:goal, creator: creator_teammate, owner: nil)
      expect(helper.goal_owner_display_name(goal)).to eq('Unknown')
    end

    context 'with department owner' do
      let(:department) { create(:department, company: company, name: 'Engineering') }

      it 'returns department display name' do
        goal = create(:goal, creator: creator_teammate, owner: department, privacy_level: 'everyone_in_company')
        expect(helper.goal_owner_display_name(goal)).to eq(department.display_name)
      end
    end
  end

  describe '#goal_prompt_association_display' do
    before { allow(helper).to receive(:company_label_for).with('reflection', 'Reflection').and_return('Reflection') }

    it 'returns nil when goal has no prompt_goals' do
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate)
      expect(helper.goal_prompt_association_display(goal)).to be_nil
    end

    it 'returns "In reflection: <template title>" when goal is associated to one prompt' do
      template = create(:prompt_template, :available, company: company, title: 'Weekly Check-in')
      prompt = create(:prompt, :open, company_teammate: creator_teammate, prompt_template: template)
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate)
      PromptGoal.create!(prompt: prompt, goal: goal)
      expect(helper.goal_prompt_association_display(goal)).to eq('In reflection: Weekly Check-in')
    end

    it 'returns comma-separated template titles when goal is associated to multiple prompts' do
      template1 = create(:prompt_template, :available, company: company, title: 'Weekly')
      template2 = create(:prompt_template, :available, company: company, title: 'Monthly')
      prompt1 = create(:prompt, :open, company_teammate: creator_teammate, prompt_template: template1)
      prompt2 = create(:prompt, :open, company_teammate: creator_teammate, prompt_template: template2)
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate)
      PromptGoal.create!(prompt: prompt1, goal: goal)
      PromptGoal.create!(prompt: prompt2, goal: goal)
      result = helper.goal_prompt_association_display(goal)
      expect(result).to include('Weekly')
      expect(result).to include('Monthly')
      expect(result).to start_with('In reflection: ')
    end
  end

  describe '#confidence_percentage_options' do
    it 'returns options from 5% to 95% in steps of 5' do
      options = helper.confidence_percentage_options
      
      expect(options).to be_an(Array)
      expect(options.length).to eq(19) # 5, 10, 15, ..., 95
      
      # Check first option
      expect(options.first).to eq(['5%', 5])
      
      # Check last option
      expect(options.last).to eq(['95%', 95])
      
      # Verify all values are multiples of 5
      values = options.map { |opt| opt[1] }
      expect(values).to all(be_a(Integer))
      expect(values).to all(be_between(5, 95))
      expect(values).to all(satisfy { |v| v % 5 == 0 })
      
      # Verify 0% and 100% are NOT included
      expect(values).not_to include(0)
      expect(values).not_to include(100)
    end
    
    it 'returns options in ascending order' do
      options = helper.confidence_percentage_options
      values = options.map { |opt| opt[1] }
      
      expect(values).to eq(values.sort)
    end
  end

  describe '#goal_index_due_phrase' do
    it 'returns "no due date" when goal has no target dates' do
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate, earliest_target_date: nil, most_likely_target_date: nil, latest_target_date: nil)
      expect(helper.goal_index_due_phrase(goal)).to eq('no due date')
    end

    it 'returns "due today" when most_likely_target_date is today' do
      today = Date.current
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate, most_likely_target_date: today, earliest_target_date: today, latest_target_date: today)
      expect(helper.goal_index_due_phrase(goal)).to eq('due today')
    end

    it 'returns "due in X" for future date' do
      future = 2.weeks.from_now.to_date
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate, most_likely_target_date: future, earliest_target_date: future, latest_target_date: future)
      expect(helper.goal_index_due_phrase(goal)).to match(/\Adue in \d+ (day|days|week|weeks|month|months)\z/)
    end

    it 'returns "due X ago" for past date' do
      past = 2.weeks.ago.to_date
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate, most_likely_target_date: past, earliest_target_date: past - 1.week, latest_target_date: past)
      expect(helper.goal_index_due_phrase(goal)).to start_with('due ').and end_with(' ago')
    end
  end

  describe '#goal_index_info_sentence' do
    it 'includes status, goal type, and due phrase for active goal' do
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate, goal_type: 'quantitative_key_result', most_likely_target_date: Date.current + 30, started_at: 1.day.ago)
      result = helper.goal_index_info_sentence(goal)
      expect(result).to be_html_safe
      expect(result).to include('Active')
      expect(result).to include('Key Result')
      expect(result).to include('due in')
    end

    it 'wraps draft status in warning styling with icon' do
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate, started_at: nil)
      result = helper.goal_index_info_sentence(goal)
      expect(result).to include('text-warning')
      expect(result).to include('bi-exclamation-triangle')
      expect(result).to include('Draft')
    end

    it 'includes "no due date" when goal has no target date' do
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate, most_likely_target_date: nil, earliest_target_date: nil, latest_target_date: nil)
      result = helper.goal_index_info_sentence(goal)
      expect(result).to include('no due date')
    end

    it 'adds popover with earliest, most likely, latest dates when goal has due date' do
      goal = create(:goal, creator: creator_teammate, owner: creator_teammate, most_likely_target_date: 1.month.from_now.to_date, earliest_target_date: 2.weeks.from_now.to_date, latest_target_date: 2.months.from_now.to_date)
      result = helper.goal_index_info_sentence(goal)
      expect(result).to include('data-bs-toggle="popover"')
      expect(result).to include('data-bs-trigger="hover"')
      expect(result).to include('Earliest:')
      expect(result).to include('Most Likely:')
      expect(result).to include('Latest:')
    end
  end

  describe '#goal_owner_image' do
    context 'with CompanyTeammate owner' do
      it 'returns div with initials when no profile image' do
        goal = create(:goal, creator: creator_teammate, owner: creator_teammate)
        result = helper.goal_owner_image(goal, size: 48)
        
        expect(result).to include('rounded-circle')
        expect(result).to include('48px')
      end

      it 'returns img tag when teammate has profile image' do
        goal = create(:goal, creator: creator_teammate, owner: creator_teammate)
        # Mock on the reloaded owner from the database
        allow(goal.owner).to receive(:profile_image_url).and_return('https://example.com/image.jpg')
        result = helper.goal_owner_image(goal, size: 48)
        
        expect(result).to include('img')
        expect(result).to include('rounded-circle')
      end
    end

    context 'with Organization owner' do
      it 'returns div with organization initials' do
        goal = create(:goal, creator: creator_teammate, owner: company, privacy_level: 'everyone_in_company')
        result = helper.goal_owner_image(goal, size: 48)
        
        expect(result).to include('rounded-circle')
        expect(result).to include('bg-secondary')
        expect(result).to include('48px')
      end
    end

    context 'with nil owner' do
      it 'returns div with question mark' do
        goal = build(:goal, creator: creator_teammate, owner: nil)
        result = helper.goal_owner_image(goal, size: 48)
        
        expect(result).to include('?')
        expect(result).to include('rounded-circle')
      end
    end

    context 'with custom size' do
      it 'respects the size parameter' do
        goal = create(:goal, creator: creator_teammate, owner: creator_teammate)
        result = helper.goal_owner_image(goal, size: 64)
        
        expect(result).to include('64px')
      end
    end
  end

  describe '#organization_initials_circle' do
    it 'returns a div with initials' do
      result = helper.organization_initials_circle('AB', size: 48)
      
      expect(result).to include('AB')
      expect(result).to include('rounded-circle')
      expect(result).to include('bg-secondary')
      expect(result).to include('48px')
    end

    it 'handles single letter initials' do
      result = helper.organization_initials_circle('X', size: 32)
      
      expect(result).to include('X')
      expect(result).to include('32px')
    end
  end
end

