require 'rails_helper'

RSpec.describe 'Organizations::Goals', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    person.teammates.find_or_initialize_by(organization: organization).tap do |t|
      t.type = 'CompanyTeammate' unless t.persisted?
      t.save! unless t.persisted?
    end
  end
  let(:goal) { create(:goal, creator: teammate, owner: teammate, title: 'Test Goal', started_at: 1.week.ago) }
  
  before do
    # Temporarily disable PaperTrail for request tests to avoid controller_info issues
    PaperTrail.enabled = false
    teammate # Ensure teammate exists before signing in
    sign_in_as_teammate_for_request(person, organization)
  end
  
  after do
    # Re-enable PaperTrail after tests
    PaperTrail.enabled = true
  end
  
  describe 'GET /organizations/:organization_id/goals/new' do
    it 'renders the new goal form' do
      get new_organization_goal_path(organization)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('New Goal')
      expect(response.body).to include('Title')
      expect(response.body).to include('Create Goal')
    end
    
    it 'defaults owner to viewing teammate' do
      get new_organization_goal_path(organization)
      
      expect(response).to have_http_status(:success)
      # Should include the teammate in the owner dropdown options
      expect(response.body).to include("Teammate: #{person.display_name}")
      # Should have the owner select field
      expect(response.body).to include('goal[owner_id]')
      # Should not include a blank/prompt option
      expect(response.body).not_to include('Select an owner')
    end
    
    it 'does not include blank option in owner dropdown' do
      get new_organization_goal_path(organization)
      
      expect(response).to have_http_status(:success)
      # Check that there's no prompt or blank option
      expect(response.body).not_to match(/<option[^>]*>Select an owner/i)
      # Verify no blank option with empty value
      expect(response.body).not_to match(/<option[^>]*value=""[^>]*><\/option>/)
      expect(response.body).not_to match(/<option[^>]*value=""><\/option>/)
      # Verify that all options have non-empty values
      option_matches = response.body.scan(/<option[^>]*value="([^"]+)"[^>]*>/)
      option_matches.each do |match|
        expect(match[0]).not_to be_blank, "Found blank option value in dropdown"
      end
    end
    
    it 'allows setting owner via query params' do
      # Create a teammate that would be in available_goal_owners (the company itself)
      get new_organization_goal_path(organization), params: {
        owner_id: "Company_#{organization.id}"
      }
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Company: #{organization.display_name}")
      # Verify the owner select has the company option
      expect(response.body).to include("value=\"Company_#{organization.id}\"")
    end
    
    it 'displays validation errors in flash when create fails' do
      post organization_goals_path(organization), params: {
        goal: {
          title: '', # Invalid - blank title
          description: 'Test description',
          goal_type: 'inspirational_objective',
          privacy_level: 'only_creator_owner_and_managers'
        }
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new)
      # Should have flash alert with validation errors
      expect(flash[:alert]).to be_present
      expect(flash[:alert]).to include('Title')
    end
    
    it 'sets creator to viewing teammate when creating goal' do
      expect {
        post organization_goals_path(organization), params: {
          goal: {
            title: 'New Goal',
            description: 'Test description',
            goal_type: 'inspirational_objective',
            privacy_level: 'only_creator_owner_and_managers',
            owner_type: 'CompanyTeammate',
            owner_id: teammate.id
          }
        }
      }.to change(Goal, :count).by(1)
      
      goal = Goal.last
      expect(goal.creator_id).to eq(teammate.id)
      expect(goal.creator).to be_a(CompanyTeammate)
      expect(goal.owner_id).to eq(teammate.id)
      expect(goal.owner).to be_a(CompanyTeammate)
    end
    
    context 'when current_teammate is missing' do
      let(:person_without_teammate) { create(:person) }
      let(:department) { create(:organization, :department, parent: organization) }
      let(:department_teammate) { create(:teammate, person: person_without_teammate, organization: department, type: 'DepartmentTeammate') }
      
      before do
        # Create a DepartmentTeammate but no CompanyTeammate for this person
        department_teammate
        # Sign in as person - this will create a CompanyTeammate, so we need to delete it
        # to simulate the scenario where person doesn't have a CompanyTeammate
        signed_in_teammate = sign_in_as_teammate_for_request(person_without_teammate, organization)
        # Delete the CompanyTeammate that was created by sign_in_as_teammate_for_request
        # This simulates the scenario where person only has a DepartmentTeammate
        signed_in_teammate.destroy
        # Stub current_person to return the person so the controller can find teammates
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person_without_teammate)
      end
      
      it 'fails with error when current_teammate is missing' do
        expect {
          post organization_goals_path(organization), params: {
            goal: {
              title: 'New Goal',
              description: 'Test description',
              goal_type: 'inspirational_objective',
              privacy_level: 'only_creator_owner_and_managers',
              owner_type: 'CompanyTeammate',
              owner_id: teammate.id
            }
          }
        }.not_to change(Goal, :count)
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
        expect(flash[:alert]).to be_present
        expect(flash[:alert]).to include('You must be a company teammate to create goals')
      end
    end
  end
  
  describe 'GET /organizations/:organization_id/goals/:id/done' do
    it 'renders the done page' do
      get done_organization_goal_path(organization, goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Mark Goal as Done')
      expect(response.body).to include(goal.title)
    end
    
    it 'loads all check-ins for the goal' do
      check_in1 = create(:goal_check_in, goal: goal, check_in_week_start: 2.weeks.ago.beginning_of_week(:monday), confidence_percentage: 75, confidence_reporter: person)
      check_in2 = create(:goal_check_in, goal: goal, check_in_week_start: 1.week.ago.beginning_of_week(:monday), confidence_percentage: 80, confidence_reporter: person)
      
      get done_organization_goal_path(organization, goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('75%')
      expect(response.body).to include('80%')
    end
    
    it 'can access done page for completed goal' do
      completed_goal = create(:goal, creator: teammate, owner: teammate, title: 'Completed Goal', started_at: 1.week.ago, completed_at: 1.day.ago)
      
      get done_organization_goal_path(organization, completed_goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Mark Goal as Done')
      expect(response.body).to include(completed_goal.title)
    end
    
    it 'accepts return_url and return_text params' do
      return_url = organization_goals_path(organization)
      return_text = 'Back to Goals'
      
      get done_organization_goal_path(organization, goal), params: {
        return_url: return_url,
        return_text: return_text
      }
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include(return_url)
    end
    
    context 'when user is not authorized' do
      let(:other_person) { create(:person) }
      let(:other_teammate) do
        other_person.teammates.find_or_initialize_by(organization: organization).tap do |t|
          t.type = 'CompanyTeammate' unless t.persisted?
          t.save! unless t.persisted?
        end
      end
      let(:other_goal) { create(:goal, creator: other_teammate, owner: other_teammate, title: 'Other Goal', started_at: 1.week.ago, privacy_level: 'only_creator') }
      
      before do
        other_teammate
        # Sign in as original person (not the creator/owner of other_goal)
        sign_in_as_teammate_for_request(person, organization)
      end
      
      it 'denies access' do
        get done_organization_goal_path(organization, other_goal)
        
        expect(response).to have_http_status(:redirect)
      end
    end
  end
  
  describe 'GET /organizations/:organization_id/goals/:id' do
    it 'displays prompt attachments when goal is attached to prompts' do
      # Ensure teammate is a CompanyTeammate by reloading from database
      teammate.update_column(:type, 'CompanyTeammate') unless teammate.type == 'CompanyTeammate'
      company_teammate = CompanyTeammate.find(teammate.id)
      
      template = create(:prompt_template, company: organization, available_at: Date.current)
      prompt = create(:prompt, company_teammate: company_teammate, prompt_template: template)
      prompt_goal = PromptGoal.create!(prompt: prompt, goal: goal)
      
      get organization_goal_path(organization, goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Associated with Prompts')
      expect(response.body).to include(template.title)
      expect(response.body).to include('Associated on')
    end
    
    it 'does not display prompt attachments section when goal has no prompts' do
      get organization_goal_path(organization, goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('Associated with Prompts')
    end
    
    it 'can access show page for completed goal' do
      completed_goal = create(:goal, creator: teammate, owner: teammate, title: 'Completed Goal', started_at: 1.week.ago, completed_at: 1.day.ago)
      
      get organization_goal_path(organization, completed_goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include(completed_goal.title)
    end
    
    it 'does not show archived child goals on goal show page' do
      active_child = create(:goal, creator: teammate, owner: teammate, title: 'Active Child Goal')
      archived_child = create(:goal, creator: teammate, owner: teammate, title: 'Archived Child Goal', deleted_at: 1.day.ago)
      create(:goal_link, parent: goal, child: active_child)
      create(:goal_link, parent: goal, child: archived_child)
      
      get organization_goal_path(organization, goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Active Child Goal')
      expect(response.body).not_to include('Archived Child Goal')
    end
    
    context 'when goal is started' do
      let(:started_goal) { create(:goal, creator: teammate, owner: teammate, title: 'Started Goal', started_at: 1.week.ago) }
      
      it 'displays check-in button for users who can edit' do
        get organization_goal_path(organization, started_goal)
        
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Check-In')
        expect(response.body).to include(weekly_update_organization_goal_path(organization, started_goal))
        # Check that the button is a link (not disabled)
        expect(response.body).to include('btn-primary')
        expect(response.body).not_to include('aria-disabled="true"')
      end
      
      it 'displays disabled check-in button with warning icon for users who cannot edit' do
        other_person = create(:person)
        other_teammate = create(:company_teammate, person: other_person, organization: organization)
        # Create a goal that the current user can view but not edit
        # Use 'everyone_in_company' privacy level which allows viewing by everyone in company
        # but editing only by creator/owner
        other_goal = create(:goal, creator: other_teammate, owner: other_teammate, title: 'Other Goal', started_at: 1.week.ago, privacy_level: 'everyone_in_company')
        
        get organization_goal_path(organization, other_goal)
        
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Check-In')
        expect(response.body).to include('disabled')
        expect(response.body).to include('aria-disabled="true"')
        expect(response.body).to include('bi-exclamation-triangle')
        expect(response.body).to include('You need permission to edit this goal to access check-ins')
      end
      
      it 'displays last check-in in sentence form when present' do
        last_week_start = Date.current.beginning_of_week(:monday) - 1.week
        last_check_in = create(:goal_check_in, 
          goal: started_goal, 
          check_in_week_start: last_week_start, 
          confidence_percentage: 75, 
          confidence_reporter: person)
        
        get organization_goal_path(organization, started_goal)
        
        expect(response).to have_http_status(:success)
        expect(response.body).to include('checked in on')
        expect(response.body).to include(person.display_name)
        expect(response.body).to include('75%')
        expect(response.body).to match(/confident we.*ll accomplish this goal/)
      end
      
      it 'displays alert when no check-ins exist' do
        get organization_goal_path(organization, started_goal)
        
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Add first check-in')
        expect(response.body).to include('alert-info')
      end
    end
  end
  
  describe 'GET /organizations/:organization_id/goals/:id/weekly_update' do
    it 'renders the weekly update page' do
      get weekly_update_organization_goal_path(organization, goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include(goal.title)
      expect(response.body).to include('Weekly Update')
      expect(response.body).to include('Current Week Check-In')
    end
    
    it 'loads all check-ins chronologically' do
      check_in1 = create(:goal_check_in, goal: goal, check_in_week_start: 3.weeks.ago.beginning_of_week(:monday), confidence_percentage: 60, confidence_reporter: person)
      check_in2 = create(:goal_check_in, goal: goal, check_in_week_start: 2.weeks.ago.beginning_of_week(:monday), confidence_percentage: 70, confidence_reporter: person)
      check_in3 = create(:goal_check_in, goal: goal, check_in_week_start: 1.week.ago.beginning_of_week(:monday), confidence_percentage: 80, confidence_reporter: person)
      
      get weekly_update_organization_goal_path(organization, goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('60%')
      expect(response.body).to include('70%')
      expect(response.body).to include('80%')
    end
    
    it 'loads current week check-in if exists' do
      current_week_start = Date.current.beginning_of_week(:monday)
      current_check_in = create(:goal_check_in, goal: goal, check_in_week_start: current_week_start, confidence_percentage: 75, confidence_reporter: person)
      
      get weekly_update_organization_goal_path(organization, goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('75%')
    end
    
    it 'displays check-ins in chronological order' do
      old_check_in = create(:goal_check_in, goal: goal, check_in_week_start: 2.weeks.ago.beginning_of_week(:monday), confidence_percentage: 60, confidence_reporter: person)
      recent_check_in = create(:goal_check_in, goal: goal, check_in_week_start: 1.week.ago.beginning_of_week(:monday), confidence_percentage: 80, confidence_reporter: person)
      
      get weekly_update_organization_goal_path(organization, goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Check-In History')
      expect(response.body).to include('60%')
      expect(response.body).to include('80%')
      # Verify they appear in chronological order (oldest first)
      old_index = response.body.index('60%')
      recent_index = response.body.index('80%')
      expect(old_index).to be < recent_index
    end
    
    it 'displays target dates section' do
      goal.update(
        earliest_target_date: Date.today + 30.days,
        most_likely_target_date: Date.today + 60.days,
        latest_target_date: Date.today + 90.days
      )
      
      get weekly_update_organization_goal_path(organization, goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Target Dates')
      expect(response.body).to include('Earliest')
      expect(response.body).to include('Most Likely')
      expect(response.body).to include('Latest')
    end
    
    it 'displays calculated target when all dates are nil' do
      goal.update(
        earliest_target_date: nil,
        most_likely_target_date: nil,
        latest_target_date: nil
      )
      
      get weekly_update_organization_goal_path(organization, goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Calculated Target')
      expect(response.body).to include('No target date calculated')
    end
    
    it 'displays goal started date if present' do
      goal.update(started_at: 2.weeks.ago)
      
      get weekly_update_organization_goal_path(organization, goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Goal Started')
    end
    
    it 'accepts return_url and return_text params' do
      return_url = organization_goals_path(organization)
      return_text = 'Back to Goals'
      
      get weekly_update_organization_goal_path(organization, goal), params: {
        return_url: return_url,
        return_text: return_text
      }
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include(return_text)
    end
    
    it 'displays check-in sentence format correctly' do
      check_in = create(:goal_check_in, goal: goal, check_in_week_start: 1.week.ago.beginning_of_week(:monday), confidence_percentage: 75, confidence_reporter: person)
      goal.update(most_likely_target_date: Date.today + 60.days)
      
      get weekly_update_organization_goal_path(organization, goal)
      
      expect(response).to have_http_status(:success)
      # Verify the sentence is rendered, not literal HAML code
      expect(response.body).to include('As of')
      expect(response.body).to include(person.display_name)
      expect(response.body).to include('75%')
      expect(response.body).to include(goal.title)
      # Verify HTML tags are rendered (not literal HAML)
      expect(response.body).to match(/<strong[^>]*>.*#{Regexp.escape(person.display_name)}/i)
      expect(response.body).to match(/<strong[^>]*>.*75%/)
      # Verify it's not showing literal HAML code (check for common HAML syntax that shouldn't appear)
      expect(response.body).not_to match(/%strong\s*=/)
      expect(response.body).not_to include('date_str')
      expect(response.body).not_to include('person_name')
    end
    
    it 'displays check-in sentence without "by" when calculated_target_date is nil' do
      check_in = create(:goal_check_in, goal: goal, check_in_week_start: 1.week.ago.beginning_of_week(:monday), confidence_percentage: 50, confidence_reporter: person)
      goal.update(most_likely_target_date: nil, earliest_target_date: nil, latest_target_date: nil)
      
      get weekly_update_organization_goal_path(organization, goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('As of')
      expect(response.body).to include(person.display_name)
      expect(response.body).to include('50%')
      expect(response.body).to include(goal.title)
      # Should not include "by" when no target date
      # The sentence should end with the goal title, not have "by" after it
      expect(response.body).not_to match(/by.*<strong[^>]*>.*#{Date.today.strftime('%B')}/)
    end
    
    it 'displays check-in sentence with "by" when calculated_target_date is present' do
      target_date = Date.today + 60.days
      check_in = create(:goal_check_in, goal: goal, check_in_week_start: 1.week.ago.beginning_of_week(:monday), confidence_percentage: 80, confidence_reporter: person)
      goal.update(most_likely_target_date: target_date)
      
      get weekly_update_organization_goal_path(organization, goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('As of')
      expect(response.body).to include(person.display_name)
      expect(response.body).to include('80%')
      expect(response.body).to include(goal.title)
      expect(response.body).to include('by')
      expect(response.body).to include(target_date.strftime('%B %d, %Y'))
    end
    
    it 'displays form with confidence dropdown and target date field' do
      get weekly_update_organization_goal_path(organization, goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('confidence_percentage')
      expect(response.body).to include('most_likely_target_date')
      expect(response.body).to include('form-select')
      expect(response.body).to include('form-control')
    end
    
    context 'when user is not authorized' do
      let(:other_person) { create(:person) }
      let(:other_teammate) do
        other_person.teammates.find_or_initialize_by(organization: organization).tap do |t|
          t.type = 'CompanyTeammate' unless t.persisted?
          t.save! unless t.persisted?
        end
      end
      let(:other_goal) { create(:goal, creator: other_teammate, owner: other_teammate, title: 'Other Goal', started_at: 1.week.ago, privacy_level: 'only_creator') }
      
      before do
        other_teammate
        sign_in_as_teammate_for_request(person, organization)
      end
      
      it 'denies access' do
        get weekly_update_organization_goal_path(organization, other_goal)
        
        expect(response).to have_http_status(:redirect)
      end
    end
  end
  
  describe 'GET /organizations/:organization_id/goals with check-in view' do
    let(:check_in_eligible_goal) do
      create(:goal, 
        creator: teammate, 
        owner: teammate, 
        title: 'Check-in Eligible Goal',
        goal_type: 'qualitative_key_result',
        most_likely_target_date: Date.today + 1.month,
        started_at: 1.week.ago
      )
    end
    
    let(:objective_goal) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Objective Goal',
        goal_type: 'inspirational_objective',
        most_likely_target_date: Date.today + 1.month,
        started_at: 1.week.ago
      )
    end
    
    let(:goal_without_date) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Goal Without Date',
        goal_type: 'qualitative_key_result',
        most_likely_target_date: nil,
        started_at: 1.week.ago
      )
    end
    
    let(:completed_goal) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Completed Goal',
        goal_type: 'quantitative_key_result',
        most_likely_target_date: Date.today + 1.month,
        started_at: 1.week.ago,
        completed_at: 1.day.ago
      )
    end
    
    it 'filters to check-in eligible goals only' do
      check_in_eligible_goal
      objective_goal
      goal_without_date
      
      get organization_goals_path(organization), params: {
        view: 'check-in',
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Check-in Eligible Goal')
      expect(response.body).not_to include('Objective Goal')
      expect(response.body).not_to include('Goal Without Date')
    end
    
    it 'loads current week check-ins' do
      current_week_start = Date.current.beginning_of_week(:monday)
      check_in = create(:goal_check_in,
        goal: check_in_eligible_goal,
        check_in_week_start: current_week_start,
        confidence_percentage: 75,
        confidence_reason: 'Making good progress',
        confidence_reporter: person
      )
      
      get organization_goals_path(organization), params: {
        view: 'check-in',
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('75%')
      expect(response.body).to include('Making good progress')
    end
    
    it 'loads recent check-ins (last 3 weeks)' do
      current_week_start = Date.current.beginning_of_week(:monday)
      week1_start = current_week_start - 1.week
      week2_start = current_week_start - 2.weeks
      week3_start = current_week_start - 3.weeks
      
      create(:goal_check_in, goal: check_in_eligible_goal, check_in_week_start: week1_start, confidence_percentage: 70, confidence_reporter: person)
      create(:goal_check_in, goal: check_in_eligible_goal, check_in_week_start: week2_start, confidence_percentage: 65, confidence_reporter: person)
      create(:goal_check_in, goal: check_in_eligible_goal, check_in_week_start: week3_start, confidence_percentage: 60, confidence_reporter: person)
      
      get organization_goals_path(organization), params: {
        view: 'check-in',
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('70%')
      expect(response.body).to include('65%')
      expect(response.body).to include('60%')
    end
    
    it 'shows completion info for completed goals instead of form fields' do
      current_week_start = Date.current.beginning_of_week(:monday)
      final_check_in = create(:goal_check_in,
        goal: completed_goal,
        check_in_week_start: current_week_start - 1.week,
        confidence_percentage: 100,
        confidence_reason: 'Successfully completed!',
        confidence_reporter: person
      )
      
      get organization_goals_path(organization), params: {
        view: 'check-in',
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id,
        show_completed: '1'
      }
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Hit')
      expect(response.body).to include('Successfully completed!')
      expect(response.body).to include(person.display_name)
      # Should not have form fields for completed goals
      expect(response.body).not_to include("goal_check_ins[#{completed_goal.id}][confidence_percentage]")
    end
    
    it 'shows "Check-in Eligible" filter in spotlight footer' do
      get organization_goals_path(organization), params: {
        view: 'check-in',
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Check-in Eligible (applied because of the view style)')
    end
    
    it 'displays current check-in week information' do
      check_in_eligible_goal # Ensure there's at least one goal to display
      current_week_start = Date.current.beginning_of_week(:monday)
      current_week_end = current_week_start.end_of_week(:sunday)
      
      get organization_goals_path(organization), params: {
        view: 'check-in',
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Current Check-in Week')
      expect(response.body).to include(current_week_start.strftime('%B %d'))
      expect(response.body).to include(current_week_end.strftime('%B %d, %Y'))
    end
    
    it 'includes form to save all goal check-ins' do
      check_in_eligible_goal # Ensure there's at least one goal to display
      
      get organization_goals_path(organization), params: {
        view: 'check-in',
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Save All Goal Check-ins')
      expect(response.body).to include(bulk_update_check_ins_organization_goals_path(organization))
    end
  end
  
  describe 'GET /organizations/:organization_id/goals with list view' do
    let(:draft_goal) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Draft Goal',
        started_at: nil
      )
    end
    
    let(:active_goal) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Active Goal',
        started_at: 1.day.ago
      )
    end
    
    it 'shows start button for draft goals when user can edit' do
      draft_goal
      active_goal
      
      get organization_goals_path(organization), params: {
        view: 'list',
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Start')
      expect(response.body).to include(start_organization_goal_path(organization, draft_goal))
      # Active goal should not have start button
      expect(response.body).not_to include(start_organization_goal_path(organization, active_goal))
    end
    
    it 'does not show start button for draft goals when user cannot edit' do
      other_person = create(:person)
      other_teammate = create(:company_teammate, person: other_person, organization: organization)
      draft_goal = create(:goal,
        creator: other_teammate,
        owner: other_teammate,
        title: 'Other Draft Goal',
        started_at: nil,
        privacy_level: 'only_creator'
      )
      
      get organization_goals_path(organization), params: {
        view: 'list',
        owner_type: 'CompanyTeammate',
        owner_id: other_teammate.id
      }
      
      expect(response).to have_http_status(:success)
      # Should not show start button if user can't edit
      expect(response.body).not_to include(start_organization_goal_path(organization, draft_goal))
    end
  end
  
  describe 'GET /organizations/:organization_id/goals with hierarchical-indented view' do
    let(:draft_goal) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Draft Goal',
        started_at: nil
      )
    end
    
    let(:active_goal) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Active Goal',
        started_at: 1.day.ago
      )
    end
    
    it 'shows start button for draft goals when user can edit' do
      draft_goal
      active_goal
      
      get organization_goals_path(organization), params: {
        view: 'hierarchical-indented',
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Start')
      expect(response.body).to include(start_organization_goal_path(organization, draft_goal))
      # Active goal should not have start button
      expect(response.body).not_to include(start_organization_goal_path(organization, active_goal))
    end
    
    it 'does not show start button for draft goals when user cannot edit' do
      other_person = create(:person)
      other_teammate = create(:company_teammate, person: other_person, organization: organization)
      draft_goal = create(:goal,
        creator: other_teammate,
        owner: other_teammate,
        title: 'Other Draft Goal',
        started_at: nil,
        privacy_level: 'only_creator'
      )
      
      get organization_goals_path(organization), params: {
        view: 'hierarchical-indented',
        owner_type: 'CompanyTeammate',
        owner_id: other_teammate.id
      }
      
      expect(response).to have_http_status(:success)
      # Should not show start button if user can't edit
      expect(response.body).not_to include(start_organization_goal_path(organization, draft_goal))
    end
  end
  
  describe 'GET /organizations/:organization_id/goals with hierarchical-collapsible view' do
    let!(:active_goal) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Active Goal',
        started_at: 1.week.ago,
        most_likely_target_date: Date.today + 30.days
      )
    end
    let!(:child_goal) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Child Goal',
        started_at: 1.week.ago,
        most_likely_target_date: Date.today + 15.days
      )
    end
    let!(:goal_link) { create(:goal_link, parent: active_goal, child: child_goal) }

    it 'renders the hierarchical-collapsible view' do
      get organization_goals_path(organization), params: {
        view: 'hierarchical-collapsible',
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Active Goal')
      expect(response.body).to include('Child Goal')
      expect(response.body).to include('tree-node')
    end

    it 'shows expand/collapse buttons' do
      get organization_goals_path(organization), params: {
        view: 'hierarchical-collapsible',
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Expand All')
      expect(response.body).to include('Collapse All')
    end

    it 'shows current check-in week banner' do
      get organization_goals_path(organization), params: {
        view: 'hierarchical-collapsible',
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Current Check-in Week')
    end

    it 'shows inline check-in forms for check-in eligible goals' do
      # Create a check-in eligible goal (quantitative_key_result with target date)
      check_in_eligible_goal = create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Check-in Eligible Goal',
        goal_type: 'quantitative_key_result',
        started_at: 1.week.ago,
        most_likely_target_date: Date.today + 30.days,
        privacy_level: 'everyone_in_company'
      )
      
      get organization_goals_path(organization), params: {
        view: 'hierarchical-collapsible',
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }
      
      expect(response).to have_http_status(:success)
      # Check for check-in form elements
      expect(response.body).to include('Confidence')
      expect(response.body).to include('Check In')
    end

    it 'shows goal hierarchy with sub-goal counts' do
      get organization_goals_path(organization), params: {
        view: 'hierarchical-collapsible',
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('1 sub-goal')
    end

    it 'shows owner image for goals' do
      get organization_goals_path(organization), params: {
        view: 'hierarchical-collapsible',
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }
      
      expect(response).to have_http_status(:success)
      # Check for profile image container classes
      expect(response.body).to include('rounded-circle')
    end
  end

  describe 'POST /organizations/:organization_id/goals/:id/complete' do
    context 'with valid data' do
      it 'creates final check-in with 100% confidence for hit' do
        expect {
          post complete_organization_goal_path(organization, goal), params: {
            completed_outcome: 'hit',
            learnings: 'We successfully completed this goal and learned valuable lessons.'
          }
        }.to change(GoalCheckIn, :count).by(1)
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_goal_path(organization, goal))
        
        final_check_in = goal.goal_check_ins.recent.first
        expect(final_check_in.confidence_percentage).to eq(100)
        expect(final_check_in.confidence_reason).to eq('We successfully completed this goal and learned valuable lessons.')
        expect(goal.reload.completed_at).to be_present
      end
      
      it 'creates final check-in with 100% confidence for hit_late' do
        expect {
          post complete_organization_goal_path(organization, goal), params: {
            completed_outcome: 'hit_late',
            learnings: 'We completed this goal but it took longer than expected.'
          }
        }.to change(GoalCheckIn, :count).by(1)
        
        final_check_in = goal.goal_check_ins.recent.first
        expect(final_check_in.confidence_percentage).to eq(100)
        expect(final_check_in.confidence_reason).to eq('We completed this goal but it took longer than expected.')
        expect(goal.reload.completed_at).to be_present
      end
      
      it 'creates final check-in with 0% confidence for miss' do
        expect {
          post complete_organization_goal_path(organization, goal), params: {
            completed_outcome: 'miss',
            learnings: 'We did not achieve this goal but learned important lessons about what went wrong.'
          }
        }.to change(GoalCheckIn, :count).by(1)
        
        final_check_in = goal.goal_check_ins.recent.first
        expect(final_check_in.confidence_percentage).to eq(0)
        expect(final_check_in.confidence_reason).to eq('We did not achieve this goal but learned important lessons about what went wrong.')
        expect(goal.reload.completed_at).to be_present
      end
      
      it 'sets completed_at on the goal' do
        expect {
          post complete_organization_goal_path(organization, goal), params: {
            completed_outcome: 'hit',
            learnings: 'Test learnings'
          }
        }.to change { goal.reload.completed_at }.from(nil)
      end
      
      it 'shows success flash message' do
        post complete_organization_goal_path(organization, goal), params: {
          completed_outcome: 'hit',
          learnings: 'Test learnings'
        }
        
        follow_redirect!
        expect(response.body).to include('Goal marked as done successfully')
      end
      
      it 'redirects to return_url when provided' do
        return_url = organization_goals_path(organization)
        
        post complete_organization_goal_path(organization, goal), params: {
          completed_outcome: 'hit',
          learnings: 'Test learnings',
          return_url: return_url
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(return_url)
      end
      
      it 'redirects to goal show page when return_url not provided' do
        post complete_organization_goal_path(organization, goal), params: {
          completed_outcome: 'hit',
          learnings: 'Test learnings'
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_goal_path(organization, goal))
      end
    end
    
    context 'with invalid data' do
      it 'requires learnings' do
        expect {
          post complete_organization_goal_path(organization, goal), params: {
            completed_outcome: 'hit',
            learnings: ''
          }
        }.not_to change(GoalCheckIn, :count)
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Learnings are required')
      end
      
      it 'requires valid completed_outcome' do
        expect {
          post complete_organization_goal_path(organization, goal), params: {
            completed_outcome: 'invalid',
            learnings: 'Test learnings'
          }
        }.not_to change(GoalCheckIn, :count)
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Invalid completion outcome')
      end
      
      it 're-renders done page with errors' do
        post complete_organization_goal_path(organization, goal), params: {
          completed_outcome: 'hit',
          learnings: ''
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Mark Goal as Done')
      end
    end
    
    context 'when user is not authorized' do
      let(:other_person) { create(:person) }
      let(:other_teammate) do
        other_person.teammates.find_or_initialize_by(organization: organization).tap do |t|
          t.type = 'CompanyTeammate' unless t.persisted?
          t.save! unless t.persisted?
        end
      end
      let(:other_goal) { create(:goal, creator: other_teammate, owner: other_teammate, title: 'Other Goal', started_at: 1.week.ago, privacy_level: 'only_creator') }
      
      before do
        other_teammate
        # Sign in as original person (not the creator/owner of other_goal)
        sign_in_as_teammate_for_request(person, organization)
      end
      
      it 'denies access' do
        expect {
          post complete_organization_goal_path(organization, other_goal), params: {
            completed_outcome: 'hit',
            learnings: 'Test learnings'
          }
        }.not_to change(GoalCheckIn, :count)
        
        expect(response).to have_http_status(:redirect)
        expect(other_goal.reload.completed_at).to be_nil
      end
    end
  end
end

