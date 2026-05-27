require 'rails_helper'

RSpec.describe 'Organizations::Goals', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) do
    person.company_teammates.find_or_create_by!(organization: organization) do |t|
      t.first_employed_at = nil
      t.last_terminated_at = nil
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

    it 'shows Owner as the first field above Title and includes Custom timeframe option' do
      get new_organization_goal_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Owner')
      expect(response.body).to include('Title')
      # Owner field (owner_id) should appear before title field in the form
      owner_field_pos = response.body.index('goal[owner_id]')
      title_field_pos = response.body.index('goal[title]')
      expect(owner_field_pos).to be < title_field_pos
      expect(response.body).to include('Custom')
      expect(response.body).to include('goal-custom-dates')
      expect(response.body).to include('timeframe_custom')
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

    it 'creates goal with Company (Organization) owner when owner_id is Company_ID format' do
      expect {
        post organization_goals_path(organization), params: {
          goal: {
            title: 'Company-Wide Goal',
            description: 'Test',
            goal_type: 'inspirational_objective',
            privacy_level: 'everyone_in_company',
            owner_id: "Company_#{organization.id}"
          }
        }
      }.to change(Goal, :count).by(1)

      created = Goal.last
      expect(created.owner_type).to eq('Organization')
      expect(created.owner_id).to eq(organization.id)
      expect(created.owner).to eq(organization)
      expect(created.privacy_level).to eq('everyone_in_company')
    end
    
    context 'when current_teammate is missing' do
      let(:person_without_teammate) { create(:person) }

      before do
        # Sign in helper stubs find(teammate_id); destroy the row then clear stubs so we do not 404 on find.
        signed_in_teammate = sign_in_as_teammate_for_request(person_without_teammate, organization)
        signed_in_teammate.destroy
        allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(nil)
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person_without_teammate)
      end

      it 'redirects before create when current_company_teammate is missing' do
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

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('session has expired')
      end
    end
  end
  
  describe 'GET /organizations/:organization_id/goals/:id/edit and PATCH update' do
    it 'edits goal with Organization owner and shows Company as selected in owner dropdown' do
      company_goal = create(:goal, creator: teammate, owner: organization, title: 'Company Goal', started_at: 1.week.ago, privacy_level: 'everyone_in_company')
      get edit_organization_goal_path(organization, company_goal)

      expect(response).to have_http_status(:success)
      # Dropdown uses "Company_ID" for the company option; edit view must show it as selected when goal.owner_type is Organization
      expect(response.body).to include("value=\"Company_#{organization.id}\"")
      expect(response.body).to include('Company Goal')
    end

    it 'shows Owner as the first field on the edit page (not in Advanced Settings)' do
      get edit_organization_goal_path(organization, goal)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Owner')
      expect(response.body).to include('goal[owner_id]')
      # Owner field should appear before Advanced Settings (owner is top-level, not inside collapse)
      owner_pos = response.body.index('Owner')
      advanced_pos = response.body.index('Advanced Settings')
      expect(owner_pos).to be < advanced_pos
    end

    it 'updates goal preserving Organization owner when owner_id is Company_ID' do
      company_goal = create(:goal, creator: teammate, owner: organization, title: 'Company Goal', started_at: 1.week.ago, privacy_level: 'everyone_in_company')
      patch organization_goal_path(organization, company_goal), params: {
        goal: {
          title: 'Updated Company Goal',
          description: company_goal.description,
          goal_type: company_goal.goal_type,
          privacy_level: 'everyone_in_company',
          owner_id: "Company_#{organization.id}"
        }
      }

      expect(response).to redirect_to(organization_goal_path(organization, company_goal))
      company_goal.reload
      expect(company_goal.title).to eq('Updated Company Goal')
      expect(company_goal.owner_type).to eq('Organization')
      expect(company_goal.owner_id).to eq(organization.id)
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
      company_teammate = teammate
      
      template = create(:prompt_template, company: organization, available_at: Date.current)
      prompt = create(:prompt, company_teammate: company_teammate, prompt_template: template)
      prompt_goal = PromptGoal.create!(prompt: prompt, goal: goal)
      
      get organization_goal_path(organization, goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Linked To')
      expect(response.body).to include(template.title)
      expect(response.body).to include('Reflection')
    end

    it 'does not display prompt attachments section when goal has no prompts' do
      get organization_goal_path(organization, goal)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('No linked records yet.')
    end

    it 'shows Observations section with goal-linked navigation' do
      get organization_goal_path(organization, goal)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('goal-observations')
      expect(response.body).to include('Observations')
      expect(response.body).to include(new_quick_note_organization_observations_path(organization, goal_id: goal.id))
      expect(response.body).to include("goal_id=#{goal.id}")
      expect(response.body).to include('view=large_list')
    end

    it 'can access show page for completed goal' do
      completed_goal = create(:goal, creator: teammate, owner: teammate, title: 'Completed Goal', started_at: 1.week.ago, completed_at: 1.day.ago)
      
      get organization_goal_path(organization, completed_goal)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include(completed_goal.title)
    end

    it 'shows completion banner with narrative sentences above goal details' do
      tz = person.timezone.presence || 'Eastern Time (US & Canada)'
      completed_at = Time.zone.parse('2026-05-15 14:30:00')
      week_start = completed_at.in_time_zone(tz).to_date.beginning_of_week(:monday)
      started_at = 3.weeks.ago
      completed_goal = create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Banner Completed Goal',
        started_at: started_at,
        completed_at: completed_at,
        earliest_target_date: Date.new(2026, 4, 1),
        most_likely_target_date: Date.new(2026, 5, 1),
        latest_target_date: Date.new(2026, 6, 1),
        initial_confidence: :commit)
      create(:goal_check_in,
        goal: completed_goal,
        confidence_reporter: person,
        check_in_week_start: week_start,
        confidence_percentage: 100,
        confidence_reason: "We shipped the MVP and iterated on feedback.")

      get organization_goal_path(organization, completed_goal)

      expect(response).to have_http_status(:success)
      banner_pos = response.body.index('goal-completion-banner-heading')
      what_pos = response.body.index('What Is This Goal?')
      expect(banner_pos).to be_present
      expect(what_pos).to be_present
      expect(banner_pos).to be < what_pos
      expect(response.body).to include('Goal completed')
      expect(response.body).to include('set out to')
      expect(response.body).to include('Banner Completed Goal')
      expect(response.body).to include('have this done by')
      expect(response.body).to include('the earliest')
      expect(response.body).to include('most likely on')
      expect(response.body).to include('the latest')
      expect(response.body).to include('Commit')
      expect(response.body).to include('confidence-level goal')
      expect(response.body).to include('marked this goal as')
      expect(response.body).to include('hit!')
      expect(response.body).to include('Here is what they learned:')
      expect(response.body).to include('We shipped the MVP')
      expect(response.body).to include('goal-completion-banner__emphasis')
      expect(response.body).not_to include('Completed on')
      expect(response.body).not_to include('Results')
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

    it 'displays Create/associate new child goal button in Actions card when user can update goal' do
      get organization_goal_path(organization, goal)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Create/associate new child goal')
      expect(response.body).to include(choose_outgoing_link_organization_goal_goal_links_path(organization, goal, goal_type: 'stepping_stone_activity'))
    end

    it 'displays Mark complete in Actions and Complete rail on current week check-in when user can update' do
      get organization_goal_path(organization, goal)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Mark complete')
      expect(response.body).to include(done_organization_goal_path(organization, goal))
      expect(response.body).to include('goal-check-in-inline-layout--triple-column')
      expect(response.body).to include('mark this goal as done and log if it was hit or not')
    end

    it 'does not display Mark complete when goal is completed' do
      completed_goal = create(:goal, creator: teammate, owner: teammate, title: 'Completed Goal', started_at: 1.week.ago, completed_at: 1.day.ago)

      get organization_goal_path(organization, completed_goal)

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('Mark complete')
      expect(response.body).not_to include('goal-check-in-inline-layout--triple-column')
    end

    it 'does not display Create/associate new child goal button when user cannot update goal' do
      other_person = create(:person)
      other_teammate = create(:company_teammate, person: other_person, organization: organization)
      other_goal = create(:goal,
        creator: other_teammate,
        owner: other_teammate,
        title: 'Other Goal',
        started_at: 1.week.ago,
        privacy_level: 'everyone_in_company',
        edit_check_in_permission: 'only_creator_and_owner')

      get organization_goal_path(organization, other_goal)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Other Goal')
      expect(response.body).not_to include('Create/associate new child goal')
    end

    context 'when goal is unstarted but check-in eligible' do
      let(:unstarted_goal) do
        create(:goal,
          creator: teammate,
          owner: teammate,
          title: 'Unstarted Key Result',
          goal_type: 'qualitative_key_result',
          started_at: nil,
          most_likely_target_date: 2.months.from_now.to_date)
      end

      it 'shows the current week check-in form with a start-on-check-in caption' do
        get organization_goal_path(organization, unstarted_goal)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Current week confidence check')
        expect(response.body).to include('Submitting a confidence check on this goal will start this goal as well.')
        expect(response.body).to include('Save confidence check')
        expect(response.body).not_to include('Start this goal to add confidence checks.')
      end
    end

    context 'when goal is started' do
      let(:started_goal) { create(:goal, creator: teammate, owner: teammate, title: 'Started Goal', started_at: 1.week.ago) }
      
      it 'displays check-in button for users who can edit' do
        get organization_goal_path(organization, started_goal)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Observations and goal confidence checks')
        expect(response.body).to include(organization_goal_path(organization, started_goal, anchor: 'check-in'))
        expect(response.body).to include('btn-primary')
        expect(response.body).not_to include('aria-disabled="true"')
      end
      
      it 'shows check-in section for a company-visible goal the viewer does not own' do
        other_person = create(:person)
        other_teammate = create(:company_teammate, person: other_person, organization: organization)
        other_goal = create(:goal, creator: other_teammate, owner: other_teammate, title: 'Other Goal', started_at: 1.week.ago, privacy_level: 'everyone_in_company')

        get organization_goal_path(organization, other_goal)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Observations and goal confidence checks')
        expect(response.body).to include('Other Goal')
        expect(response.body).to include('Current week confidence check')
      end

      it 'does not link Mark complete or Complete rail when viewer cannot update the goal' do
        other_person = create(:person)
        other_teammate = create(:company_teammate, person: other_person, organization: organization)
        other_goal = create(:goal,
          creator: other_teammate,
          owner: other_teammate,
          title: 'Other Goal',
          started_at: 1.week.ago,
          privacy_level: 'everyone_in_company',
          edit_check_in_permission: 'only_creator_and_owner')

        get organization_goal_path(organization, other_goal)

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include(done_organization_goal_path(organization, other_goal))
        expect(response.body).not_to include('goal-check-in-inline-layout--triple-column')
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
        expect(response.body).to include('reports a')
        expect(response.body).to include(person.display_name)
        expect(response.body).to include('75%')
        expect(response.body).to include('confidence we will achieve')
      end
      
      it 'displays alert when no check-ins exist' do
        get organization_goal_path(organization, started_goal)

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('Confidence check history')
        expect(response.body).to include('Current week confidence check')
      end

      it 'displays Progress card with chart when goal has check-ins and target date' do
        started_goal.update!(most_likely_target_date: 1.month.from_now)
        create(:goal_check_in, goal: started_goal, check_in_week_start: 1.week.ago.beginning_of_week(:monday), confidence_percentage: 80, confidence_reporter: person)

        get organization_goal_path(organization, started_goal)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('goal-progress-confidence-chart')
        expect(response.body).to include('Confidence vs. On-Track Thresholds')
      end

      it 'does not display progress chart when goal has no target dates' do
        started_goal.update!(
          most_likely_target_date: nil,
          earliest_target_date: nil,
          latest_target_date: nil
        )

        get organization_goal_path(organization, started_goal)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Target Dates')
        expect(response.body).not_to include('goal-progress-confidence-chart')
        expect(response.body).not_to include('Confidence vs. On-Track Thresholds')
      end
    end
  end
  
  describe 'GET /organizations/:organization_id/goals/:id/weekly_update' do
    # weekly_update action redirects to goal show (#check-in); follow for body assertions.
    def follow_weekly_update_redirect!(org = organization, g = goal)
      expect(response).to redirect_to(organization_goal_path(org, g, anchor: 'check-in'))
      follow_redirect!
      expect(response).to have_http_status(:success)
    end

    it 'redirects to goal show check-in anchor (merged weekly update UI)' do
      get weekly_update_organization_goal_path(organization, goal)

      follow_weekly_update_redirect!
      expect(response.body).to include(goal.title)
      expect(response.body).to include('Current week confidence check')
    end
    
    it 'loads all check-ins chronologically' do
      check_in1 = create(:goal_check_in, goal: goal, check_in_week_start: 3.weeks.ago.beginning_of_week(:monday), confidence_percentage: 60, confidence_reporter: person)
      check_in2 = create(:goal_check_in, goal: goal, check_in_week_start: 2.weeks.ago.beginning_of_week(:monday), confidence_percentage: 70, confidence_reporter: person)
      check_in3 = create(:goal_check_in, goal: goal, check_in_week_start: 1.week.ago.beginning_of_week(:monday), confidence_percentage: 80, confidence_reporter: person)
      
      get weekly_update_organization_goal_path(organization, goal)
      follow_weekly_update_redirect!
      expect(response.body).to include('60%')
      expect(response.body).to include('70%')
      expect(response.body).to include('80%')
    end
    
    it 'loads current week check-in if exists' do
      current_week_start = Date.current.beginning_of_week(:monday)
      current_check_in = create(:goal_check_in, goal: goal, check_in_week_start: current_week_start, confidence_percentage: 75, confidence_reporter: person)
      
      get weekly_update_organization_goal_path(organization, goal)
      follow_weekly_update_redirect!
      expect(response.body).to include('75%')
    end
    
    it 'displays check-ins in chronological order' do
      old_check_in = create(:goal_check_in, goal: goal, check_in_week_start: 2.weeks.ago.beginning_of_week(:monday), confidence_percentage: 60, confidence_reporter: person)
      recent_check_in = create(:goal_check_in, goal: goal, check_in_week_start: 1.week.ago.beginning_of_week(:monday), confidence_percentage: 80, confidence_reporter: person)

      get weekly_update_organization_goal_path(organization, goal)
      follow_weekly_update_redirect!
      expect(response.body).to include('Confidence check history')
      expect(response.body).to include('60%')
      expect(response.body).to include('80%')
      # Verify they appear in chronological order (oldest first) within confidence check history
      # (avoid matching percentages in the Current Week form dropdown)
      body = response.body
      history_start = body.index('Confidence check history')
      history_end = body.index('Current week confidence check') || body.length
      history_section = body[history_start...history_end]
      old_index = history_section.index('60%')
      recent_index = history_section.index('80%')
      expect(old_index).to be < recent_index
    end
    
    it 'displays target dates section' do
      goal.update(
        earliest_target_date: Date.today + 30.days,
        most_likely_target_date: Date.today + 60.days,
        latest_target_date: Date.today + 90.days
      )
      
      get weekly_update_organization_goal_path(organization, goal)
      follow_weekly_update_redirect!
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
      follow_weekly_update_redirect!
      expect(response.body).to include('Calculated Target')
      expect(response.body).to include('No target date calculated')
    end
    
    it 'displays goal started date if present' do
      goal.update(started_at: 2.weeks.ago)
      
      get weekly_update_organization_goal_path(organization, goal)
      follow_weekly_update_redirect!
      expect(response.body).to include('Goal Started')
    end

    it 'includes progress confidence chart when goal has target dates and started_at' do
      goal.update!(
        started_at: 4.weeks.ago,
        earliest_target_date: 2.weeks.from_now.to_date,
        most_likely_target_date: 6.weeks.from_now.to_date,
        latest_target_date: 10.weeks.from_now.to_date
      )
      get weekly_update_organization_goal_path(organization, goal)
      follow_weekly_update_redirect!
      expect(response.body).to include('goal-progress-confidence-chart')
      expect(response.body).to include('Confidence vs. On-Track Thresholds')
    end

    it 'does not include progress chart when goal has no target dates' do
      goal.update!(earliest_target_date: nil, most_likely_target_date: nil, latest_target_date: nil)
      get weekly_update_organization_goal_path(organization, goal)
      follow_weekly_update_redirect!
      expect(response.body).not_to include('goal-progress-confidence-chart')
    end
    
    it 'accepts return_url and return_text params' do
      return_url = organization_goals_path(organization)
      return_text = 'Back to Goals'
      
      get weekly_update_organization_goal_path(organization, goal), params: {
        return_url: return_url,
        return_text: return_text
      }

      follow_weekly_update_redirect!
      expect(response.body).to include(goal.title)
    end
    
    it 'displays check-in sentence format correctly' do
      check_in = create(:goal_check_in, goal: goal, check_in_week_start: 1.week.ago.beginning_of_week(:monday), confidence_percentage: 75, confidence_reporter: person)
      goal.update(most_likely_target_date: Date.today + 60.days)
      
      get weekly_update_organization_goal_path(organization, goal)
      follow_weekly_update_redirect!
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
      follow_weekly_update_redirect!
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
      follow_weekly_update_redirect!
      expect(response.body).to include('As of')
      expect(response.body).to include(person.display_name)
      expect(response.body).to include('80%')
      expect(response.body).to include(goal.title)
      expect(response.body).to include('by')
      expect(response.body).to include(target_date.strftime('%B %d, %Y'))
    end
    
    it 'displays form with confidence dropdown and target date field' do
      get weekly_update_organization_goal_path(organization, goal)
      follow_weekly_update_redirect!
      expect(response.body).to include('confidence_percentage')
      expect(response.body).to include('most_likely_target_date')
      expect(response.body).to include('form-select')
      expect(response.body).to include('form-control')
    end
    
    context 'when user is not authorized' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { other_person.company_teammates.find_or_create_by!(organization: organization) { |t| t.first_employed_at = nil; t.last_terminated_at = nil } }
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
  
  describe 'GET /organizations/:organization_id/goals with default (hierarchical-collapsible) view' do
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

    it 'shows mark-done button with tooltip for active check-in-eligible goals' do
      check_in_eligible_goal

      get organization_goals_path(organization), params: {
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(done_organization_goal_path(organization, check_in_eligible_goal))
      expect(response.body).to include('mark this goal as done and log if it was hit or not')
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
      expect(response.body).to include('Current confidence check week')
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
      # Check-in form uses sentence: "I'm [dropdown] confident this'll be hit by [date]."
      expect(response.body).to include('confident this\'ll be hit by')
      expect(response.body).to include('Check In')
    end

    it 'does not show View button for vision goals (only view would be shown)' do
      vision_goal = create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'My Vision',
        goal_type: 'inspirational_objective',
        most_likely_target_date: nil,
        started_at: 1.week.ago,
        privacy_level: 'everyone_in_company'
      )
      get organization_goals_path(organization), params: {
        view: 'hierarchical-collapsible',
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }
      expect(response).to have_http_status(:success)
      expect(response.body).to include('My Vision')
      # Vision goal card must not contain the View button (we hide it when vision would only show View)
      # Find the card containing "My Vision" and ensure it has no View button (btn-outline-primary + View)
      idx = response.body.index('My Vision')
      expect(idx).to be_present
      # Card content: from start of this tree-node back to previous tree-node or start, then forward to end of card
      start_idx = response.body.rindex('tree-node', idx) || 0
      end_idx = response.body.index('tree-node', idx + 1) || response.body.length
      vision_card_html = response.body[start_idx...end_idx]
      expect(vision_card_html).not_to include('btn-outline-primary')
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

    context 'when viewer is not the teammate owner' do
      let(:other_person) { create(:person) }
      let!(:other_teammate) do
        other_person.company_teammates.find_or_create_by!(organization: organization) do |t|
          t.first_employed_at = nil
          t.last_terminated_at = nil
        end
      end
      let!(:shared_teammate_owned_goal) do
        create(:goal,
          creator: teammate,
          owner: teammate,
          title: 'Teammate Owned KR For Others',
          goal_type: 'quantitative_key_result',
          privacy_level: 'everyone_in_company',
          edit_check_in_permission: 'only_creator_and_owner',
          started_at: 1.week.ago,
          most_likely_target_date: Date.today + 30.days)
      end

      before do
        sign_in_as_teammate_for_request(other_person, organization)
      end

      it 'shows full-width quick note link instead of disabled check-in for teammate-owned key result' do
        get organization_goals_path(organization), params: {
          view: 'hierarchical-collapsible',
          owner_id: 'everyone_in_company'
        }
        expect(response).to have_http_status(:success)
        idx = response.body.index('Teammate Owned KR For Others')
        expect(idx).not_to be_nil
        window = response.body[idx, 4000]
        expect(window).to include('Add a note/win/challenge about this goal')
        expect(window).to include("goal_id=#{shared_teammate_owned_goal.id}")
        expect(window).not_to include("goal_check_in_disabled_#{shared_teammate_owned_goal.id}")
      end
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
      let(:other_teammate) { other_person.company_teammates.find_or_create_by!(organization: organization) { |t| t.first_employed_at = nil; t.last_terminated_at = nil } }
      let(:other_goal) { create(:goal, creator: other_teammate, owner: other_teammate, title: 'Other Goal', started_at: 1.week.ago, privacy_level: 'only_creator') }

      before do
        other_teammate
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

  describe 'GET /organizations/:organization_id/goals index with prompt_id filter' do
    let(:template) { create(:prompt_template, :available, company: organization) }
    let(:prompt) { create(:prompt, :open, company_teammate: teammate, prompt_template: template) }
    let!(:prompt_goal) { create(:goal, creator: teammate, owner: teammate, title: 'Goal for reflection', started_at: 1.week.ago) }
    let!(:unlinked_goal) { create(:goal, creator: teammate, owner: teammate, title: 'Unlinked goal', started_at: 1.week.ago) }

    before do
      PromptGoal.create!(prompt: prompt, goal: prompt_goal)
    end

    it 'restricts goals to prompt-associated goals only (excludes unlinked goals)' do
      get organization_goals_path(organization, owner_type: 'CompanyTeammate', owner_id: teammate.id, prompt_id: prompt.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Goal for reflection')
      expect(response.body).not_to include('Unlinked goal')
    end

    it 'includes prompt-associated goals and all their descendants (children, grandchildren)' do
      root = create(:goal, creator: teammate, owner: teammate, title: 'Root on prompt', started_at: 1.week.ago)
      child = create(:goal, creator: teammate, owner: teammate, title: 'Child of root', started_at: 1.week.ago)
      grandchild = create(:goal, creator: teammate, owner: teammate, title: 'Grandchild', started_at: 1.week.ago)
      GoalLink.create!(parent: root, child: child)
      GoalLink.create!(parent: child, child: grandchild)
      PromptGoal.create!(prompt: prompt, goal: root)

      get organization_goals_path(organization, owner_type: 'CompanyTeammate', owner_id: teammate.id, prompt_id: prompt.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Root on prompt')
      expect(response.body).to include('Child of root')
      expect(response.body).to include('Grandchild')
    end

    it 'excludes goals that are only descendants of goals not on the prompt' do
      root_on_prompt = create(:goal, creator: teammate, owner: teammate, title: 'Only root on prompt', started_at: 1.week.ago)
      PromptGoal.create!(prompt: prompt, goal: root_on_prompt)

      unlinked_parent = create(:goal, creator: teammate, owner: teammate, title: 'Unlinked parent', started_at: 1.week.ago)
      child_of_unlinked = create(:goal, creator: teammate, owner: teammate, title: 'Child of unlinked', started_at: 1.week.ago)
      GoalLink.create!(parent: unlinked_parent, child: child_of_unlinked)

      get organization_goals_path(organization, owner_type: 'CompanyTeammate', owner_id: teammate.id, prompt_id: prompt.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Only root on prompt')
      expect(response.body).not_to include('Unlinked parent')
      expect(response.body).not_to include('Child of unlinked')
    end

    it 'shows information pill with prompt template name in spotlight footer when filtered by prompt' do
      get organization_goals_path(organization, owner_type: 'CompanyTeammate', owner_id: teammate.id, prompt_id: prompt.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Goals for:')
      expect(response.body).to include(template.title)
    end
  end

  describe 'GET /organizations/:organization_id/goals index page owner dropdown' do
    it 'includes the created_by_me option in the owner dropdown' do
      get organization_goals_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('All goals created by me')
      expect(response.body).to include('value="created_by_me"')
    end

    it 'filters goals by creator when created_by_me is selected' do
      other_person = create(:person)
      other_teammate = other_person.company_teammates.find_or_create_by!(organization: organization) { |t| t.first_employed_at = nil; t.last_terminated_at = nil }

      my_goal = create(:goal, creator: teammate, owner: teammate, title: 'My Goal')
      other_goal = create(:goal, creator: other_teammate, owner: other_teammate,
                          privacy_level: 'everyone_in_company', title: 'Other Goal')

      get organization_goals_path(organization, owner_id: 'created_by_me')

      expect(response).to have_http_status(:success)
      expect(response.body).to include('My Goal')
      expect(response.body).not_to include('Other Goal')
    end
  end

  describe 'goal owner options include full managerial hierarchy' do
    let(:direct_report_person) { create(:person, first_name: 'Direct', last_name: 'Report') }
    let(:indirect_report_person) { create(:person, first_name: 'Indirect', last_name: 'Report') }
    let(:direct_report_teammate) do
      direct_report_person.company_teammates.find_or_create_by!(organization: organization) do |t|
        t.first_employed_at = nil
        t.last_terminated_at = nil
      end
    end
    let(:indirect_report_teammate) do
      indirect_report_person.company_teammates.find_or_create_by!(organization: organization) do |t|
        t.first_employed_at = nil
        t.last_terminated_at = nil
      end
    end

    before do
      create(:employment_tenure, company: organization, company_teammate: direct_report_teammate, manager_teammate: teammate, ended_at: nil)
      create(:employment_tenure, company: organization, company_teammate: indirect_report_teammate, manager_teammate: direct_report_teammate, ended_at: nil)
    end

    it 'shows indirect reports in the index owner filter switcher' do
      get organization_goals_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(direct_report_person.casual_name)
      expect(response.body).to include(indirect_report_person.casual_name)
    end

    it 'shows indirect reports in the single create owner dropdown' do
      get new_organization_goal_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Teammate: #{direct_report_person.display_name}")
      expect(response.body).to include("Teammate: #{indirect_report_person.display_name}")
    end

    it 'shows indirect reports in the bulk create owner dropdown' do
      get bulk_new_organization_goals_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Teammate: #{direct_report_person.display_name}")
      expect(response.body).to include("Teammate: #{indirect_report_person.display_name}")
    end
  end

  describe 'GET /organizations/:organization_id/goals index by owner/filter type' do
    it 'loads the index with default (current teammate) and shows only that teammate\'s goals' do
      my_goal = create(:goal, creator: teammate, owner: teammate, title: 'My Teammate Goal', started_at: 1.week.ago)
      other_person = create(:person)
      other_teammate = other_person.company_teammates.find_or_create_by!(organization: organization) { |t| t.first_employed_at = nil; t.last_terminated_at = nil }
      other_goal = create(:goal, creator: other_teammate, owner: other_teammate, title: 'Other Teammate Goal', started_at: 1.week.ago)

      get organization_goals_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('My Teammate Goal')
      expect(response.body).not_to include('Other Teammate Goal')
    end

    it 'loads the index for a specific CompanyTeammate and shows only that teammate\'s goals' do
      other_person = create(:person)
      other_teammate = other_person.company_teammates.find_or_create_by!(organization: organization) { |t| t.first_employed_at = nil; t.last_terminated_at = nil }
      other_goal = create(:goal, creator: other_teammate, owner: other_teammate, title: 'Other Teammate Goal', started_at: 1.week.ago)
      my_goal = create(:goal, creator: teammate, owner: teammate, title: 'My Teammate Goal', started_at: 1.week.ago)

      get organization_goals_path(organization, owner_id: "CompanyTeammate_#{other_teammate.id}")

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Other Teammate Goal')
      expect(response.body).not_to include('My Teammate Goal')
      expect(response.body).to include("Add goals for #{other_person.max_two_initials}")
    end

    it 'loads the index for Organization (Company) owner and shows only company-owned goals' do
      company_goal = create(:goal, creator: teammate, owner: organization, title: 'Company-Wide Goal', started_at: 1.week.ago)
      teammate_goal = create(:goal, creator: teammate, owner: teammate, title: 'My Personal Goal', started_at: 1.week.ago)

      get organization_goals_path(organization, owner_id: "Company_#{organization.id}")

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Company-Wide Goal')
      expect(response.body).not_to include('My Personal Goal')
    end

    it 'loads the index for Department owner and shows only department-owned goals' do
      department = create(:department, company: organization, name: 'Engineering')
      department_goal = create(:goal, creator: teammate, owner: department, title: 'Department Goal', started_at: 1.week.ago)
      teammate_goal = create(:goal, creator: teammate, owner: teammate, title: 'My Personal Goal', started_at: 1.week.ago)

      get organization_goals_path(organization, owner_id: "Department_#{department.id}")

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Department Goal')
      expect(response.body).not_to include('My Personal Goal')
    end

    it 'loads the index for Team owner and shows only team-owned goals' do
      team = create(:team, company: organization, name: 'Product Team')
      team_goal = create(:goal, creator: teammate, owner: team, title: 'Team Goal', started_at: 1.week.ago)
      teammate_goal = create(:goal, creator: teammate, owner: teammate, title: 'My Personal Goal', started_at: 1.week.ago)

      get organization_goals_path(organization, owner_id: "Team_#{team.id}")

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Team Goal')
      expect(response.body).not_to include('My Personal Goal')
    end

    it 'loads the index for "created_by_me" and shows only goals created by current teammate' do
      my_goal = create(:goal, creator: teammate, owner: teammate, title: 'Created By Me', started_at: 1.week.ago)
      other_person = create(:person)
      other_teammate = other_person.company_teammates.find_or_create_by!(organization: organization) { |t| t.first_employed_at = nil; t.last_terminated_at = nil }
      other_goal = create(:goal, creator: other_teammate, owner: other_teammate, title: 'Created By Other', started_at: 1.week.ago)

      get organization_goals_path(organization, owner_id: 'created_by_me')

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Created By Me')
      expect(response.body).not_to include('Created By Other')
    end

    it 'loads the index for "All goals visible to everyone at <Company>" and shows only public (everyone_in_company) goals' do
      organization.update!(name: 'Acme Corp') # ensure display_name for dropdown
      public_goal = create(:goal, creator: teammate, owner: teammate, title: 'Public Goal', privacy_level: 'everyone_in_company', started_at: 1.week.ago)
      private_goal = create(:goal, creator: teammate, owner: teammate, title: 'Private Goal', privacy_level: 'only_creator', started_at: 1.week.ago)

      get organization_goals_path(organization, owner_id: 'everyone_in_company')

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Public Goal')
      expect(response.body).not_to include('Private Goal')
    end

    it 'when "All goals visible to everyone at Organization" is selected, shows all public goals in the org and ignores owner' do
      organization.update!(name: 'Acme Corp')
      other_person = create(:person)
      other_teammate = other_person.company_teammates.find_or_create_by!(organization: organization) { |t| t.first_employed_at = nil; t.last_terminated_at = nil }
      department = create(:department, company: organization, name: 'Engineering')
      team = create(:team, company: organization, name: 'Product')

      # Public goals with different owners — all should appear (owner is ignored)
      public_teammate_goal = create(:goal, creator: teammate, owner: teammate, title: 'Public Teammate Goal', privacy_level: 'everyone_in_company', started_at: 1.week.ago)
      public_other_teammate_goal = create(:goal, creator: other_teammate, owner: other_teammate, title: 'Public Other Teammate Goal', privacy_level: 'everyone_in_company', started_at: 1.week.ago)
      public_company_goal = create(:goal, creator: teammate, owner: organization, title: 'Public Company Goal', privacy_level: 'everyone_in_company', started_at: 1.week.ago)
      public_department_goal = create(:goal, creator: teammate, owner: department, title: 'Public Department Goal', privacy_level: 'everyone_in_company', started_at: 1.week.ago)
      public_team_goal = create(:goal, creator: teammate, owner: team, title: 'Public Team Goal', privacy_level: 'everyone_in_company', started_at: 1.week.ago)

      # Private goal — must not appear
      private_goal = create(:goal, creator: teammate, owner: teammate, title: 'Private Goal', privacy_level: 'only_creator', started_at: 1.week.ago)

      get organization_goals_path(organization, owner_id: 'everyone_in_company')

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Public Teammate Goal')
      expect(response.body).to include('Public Other Teammate Goal')
      expect(response.body).to include('Public Company Goal')
      expect(response.body).to include('Public Department Goal')
      expect(response.body).to include('Public Team Goal')
      expect(response.body).not_to include('Private Goal')
    end

    it 'when "All goals visible to everyone" is selected, includes public draft goals (does not require started_at)' do
      organization.update!(name: 'Acme Corp')
      public_draft = create(:goal, creator: teammate, owner: teammate, title: 'Public Draft Goal', privacy_level: 'everyone_in_company', started_at: nil)
      public_started = create(:goal, creator: teammate, owner: teammate, title: 'Public Started Goal', privacy_level: 'everyone_in_company', started_at: 1.week.ago)

      get organization_goals_path(organization, owner_id: 'everyone_in_company')

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Public Draft Goal')
      expect(response.body).to include('Public Started Goal')
    end

    it 'when "All goals visible to everyone" is selected with show_completed=1, includes public completed goals' do
      organization.update!(name: 'Acme Corp')
      public_completed = create(:goal, creator: teammate, owner: teammate, title: 'Public Completed Goal', privacy_level: 'everyone_in_company', started_at: 1.week.ago, completed_at: 1.day.ago)
      public_active = create(:goal, creator: teammate, owner: teammate, title: 'Public Active Goal', privacy_level: 'everyone_in_company', started_at: 1.week.ago)

      get organization_goals_path(organization, owner_id: 'everyone_in_company', show_completed: '1')

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Public Completed Goal')
      expect(response.body).to include('Public Active Goal')
    end

    it 'displays "All goals visible to everyone at <Company name>" label when everyone_in_company filter is selected' do
      organization.update!(name: 'Acme Corp')

      get organization_goals_path(organization, owner_id: 'everyone_in_company')

      expect(response).to have_http_status(:success)
      expect(response.body).to include('All goals visible to everyone at Acme Corp')
    end

    it 'displays Company as selected in primary filter when Company owner is selected' do
      organization.update!(name: 'Acme Corp')
      create(:goal, creator: teammate, owner: organization, title: 'Company Goal', started_at: 1.week.ago)

      get organization_goals_path(organization, owner_id: "Company_#{organization.id}")

      expect(response).to have_http_status(:success)
      expect(response.body).to match(/selected="selected" value="Company_#{organization.id}"/)
      expect(response.body).to include('Company Goal')
    end

    it 'index page shows goals header switcher and optgroups' do
      get organization_goals_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Goals for')
      expect(response.body).to include('<optgroup label="Filter">')
      expect(response.body).to include('<optgroup label="Teammates">')
      expect(response.body).to include('<optgroup label="Company">')
    end
  end

  describe 'GET /organizations/:organization_id/goals status toggles' do
    let!(:draft_goal) { create(:goal, creator: teammate, owner: teammate, title: 'Status Draft Goal', started_at: nil) }
    let!(:active_goal) { create(:goal, creator: teammate, owner: teammate, title: 'Status Active Goal', started_at: 1.week.ago) }
    let!(:completed_goal) { create(:goal, creator: teammate, owner: teammate, title: 'Status Completed Goal', started_at: 1.week.ago, completed_at: 1.day.ago) }
    let!(:archived_goal) { create(:goal, creator: teammate, owner: teammate, title: 'Status Archived Goal', started_at: 1.week.ago, deleted_at: 1.day.ago) }

    it 'defaults to showing draft and active while hiding completed and archived' do
      get organization_goals_path(organization), params: {
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Status Draft Goal')
      expect(response.body).to include('Status Active Goal')
      expect(response.body).not_to include('Status Completed Goal')
      expect(response.body).not_to include('Status Archived Goal')
    end

    it 'includes completed and archived when those status toggles are selected' do
      get organization_goals_path(organization), params: {
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id,
        status: %w[draft active completed archived]
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Status Draft Goal')
      expect(response.body).to include('Status Active Goal')
      expect(response.body).to include('Status Completed Goal')
      expect(response.body).to include('Status Archived Goal')
    end
  end

  describe 'GET /organizations/:organization_id/goals/customize_view status labels' do
    it 'shows Archived label and does not show deleted wording' do
      get customize_view_organization_goals_path(organization), params: {
        owner_type: 'CompanyTeammate',
        owner_id: teammate.id
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Archived')
      expect(response.body).not_to include('Show deleted goals')
    end
  end

  describe 'GET /organizations/:organization_id/goals/bulk_new' do
    it 'renders the bulk create form with owner dropdown' do
      get bulk_new_organization_goals_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Bulk create goals')
      expect(response.body).to include('Owner')
      expect(response.body).to include('bulk-goal-owner-select')
      expect(response.body).to include('Insert a 3-layer example')
      expect(response.body).to include('data-controller="bulk-goals-example"')
    end

    it 'includes teammate options in owner dropdown' do
      get bulk_new_organization_goals_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(person.display_name)
      expect(response.body).to include("CompanyTeammate_#{teammate.id}")
    end

    it 'includes company option in owner dropdown' do
      get bulk_new_organization_goals_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Company: #{organization.display_name}")
      expect(response.body).to include("Company_#{organization.id}")
    end

    it 'does not include everyone_in_company filter option in owner dropdown' do
      get bulk_new_organization_goals_path(organization)

      expect(response).to have_http_status(:success)
      # The "All goals visible to everyone" option should NOT be present for bulk create
      expect(response.body).not_to include('value="everyone_in_company"')
    end

    it 'does not include created_by_me filter option in owner dropdown' do
      get bulk_new_organization_goals_path(organization)

      expect(response).to have_http_status(:success)
      # The "All goals created by me" option should NOT be present for bulk create
      expect(response.body).not_to include('value="created_by_me"')
    end

    it 'defaults to current teammate when no owner_id param provided' do
      get bulk_new_organization_goals_path(organization)

      expect(response).to have_http_status(:success)
      # Should have current teammate selected
      expect(response.body).to include("selected=\"selected\" value=\"CompanyTeammate_#{teammate.id}\"")
    end

    it 'shows informational text about privacy defaults' do
      get bulk_new_organization_goals_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('everyone in the company')
      expect(response.body).to include('creator, owner, and managers')
    end

    it 'orders owner dropdown: viewing teammate first, then company, then departments hierarchically' do
      dept_aaa = create(:department, company: organization, name: 'AAA', parent_department: nil)
      dept_bbb = create(:department, company: organization, name: 'BBB', parent_department: nil)
      create(:department, company: organization, name: 'Sub-B1', parent_department: dept_bbb)

      get bulk_new_organization_goals_path(organization)

      expect(response).to have_http_status(:success)
      body = response.body
      # Viewing teammate option appears before company
      teammate_pos = body.index("CompanyTeammate_#{teammate.id}")
      company_pos = body.index("Company: #{organization.display_name}")
      expect(teammate_pos).to be < company_pos
      # Departments appear in hierarchical order: AAA, then BBB, then BBB > Sub-B1 (HTML-escaped >)
      expect(body).to include('AAA')
      expect(body).to include('BBB')
      expect(body).to include('Sub-B1')
      pos_aaa = body.index('AAA')
      pos_bbb = body.index('BBB')
      pos_sub = body.index('Sub-B1')
      expect(pos_aaa).to be < pos_bbb
      expect(pos_bbb).to be < pos_sub
    end
  end

  describe 'POST /organizations/:organization_id/goals/bulk_create' do
    it 'creates goals with teammate owner and correct privacy level' do
      expect {
        post bulk_create_organization_goals_path(organization), params: {
          owner_id: "CompanyTeammate_#{teammate.id}",
          bulk_goal_titles: "Test Goal 1\nTest Goal 2"
        }
      }.to change(Goal, :count).by(2)

      created_goals = Goal.last(2)
      created_goals.each do |goal|
        expect(goal.owner_id).to eq(teammate.id)
        expect(goal.owner_type).to eq('CompanyTeammate')
        expect(goal.privacy_level).to eq('only_creator_owner_and_managers')
      end
    end

    it 'creates goals with company owner and everyone_in_company privacy' do
      expect {
        post bulk_create_organization_goals_path(organization), params: {
          owner_id: "Company_#{organization.id}",
          bulk_goal_titles: "Company Goal"
        }
      }.to change(Goal, :count).by(1)

      created_goal = Goal.last
      expect(created_goal.owner_id).to eq(organization.id)
      expect(created_goal.owner_type).to eq('Organization')
      expect(created_goal.privacy_level).to eq('everyone_in_company')
    end
  end
end

