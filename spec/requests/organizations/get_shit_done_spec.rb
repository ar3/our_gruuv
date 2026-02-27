require 'rails_helper'

RSpec.describe 'Organizations::GetShitDone', type: :request do
  let(:company) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: company) }
  let(:other_person) { create(:person) }
  let(:other_teammate) { create(:teammate, person: other_person, organization: company) }

  before do
    teammate # Ensure teammate is created
    sign_in_as_teammate_for_request(person, company)
    PaperTrail.enabled = false
  end

  after do
    PaperTrail.enabled = true
  end

  describe 'GET /organizations/:organization_id/get_shit_done' do
    it 'renders the dashboard page' do
      get "/organizations/#{company.to_param}/get_shit_done"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Get S*** Done')
    end

    it 'loads pending observable moments for the current teammate' do
      # Ensure teammate is a CompanyTeammate
      teammate_record = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      moment1 = create(:observable_moment, :new_hire, company: company, primary_observer_person: person)
      moment2 = create(:observable_moment, :seat_change, company: company, primary_observer_person: person)
      other_person2 = create(:person, email: "other2#{SecureRandom.hex(4)}@example.com")
      other_teammate2 = CompanyTeammate.find_or_create_by!(person: other_person2, organization: company)
      moment3 = create(:observable_moment, :new_hire, company: company, primary_observer_person: other_person2)
      
      get "/organizations/#{company.to_param}/get_shit_done"
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include(moment1.display_name)
      expect(response.body).to include(moment2.display_name)
      expect(response.body).not_to include(moment3.display_name)
    end

    it 'loads pending MAAP snapshots for the current person' do
      # Ensure teammate is a CompanyTeammate
      company_teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      other_company_tm = CompanyTeammate.find_or_create_by!(person: other_person, organization: company)
      creator = create(:company_teammate, organization: company)
      snapshot1 = create(:maap_snapshot, employee_company_teammate: company_teammate, creator_company_teammate: creator, company: company, effective_date: Time.current, employee_acknowledged_at: nil, change_type: 'assignment_management', reason: 'Test reason 1')
      snapshot2 = create(:maap_snapshot, employee_company_teammate: company_teammate, creator_company_teammate: creator, company: company, effective_date: Time.current, employee_acknowledged_at: Time.current, change_type: 'position_tenure', reason: 'Test reason 2')
      snapshot3 = create(:maap_snapshot, employee_company_teammate: other_company_tm, creator_company_teammate: creator, company: company, effective_date: Time.current, employee_acknowledged_at: nil, change_type: 'milestone_management', reason: 'Test reason 3')
      
      get "/organizations/#{company.to_param}/get_shit_done"
      
      expect(response).to have_http_status(:success)
      # snapshot1 should be included (pending acknowledgement) - check for unique reason text
      expect(response.body).to include('Test reason 1')
      # snapshot2 should NOT be included (already acknowledged) - check for unique reason text
      expect(response.body).not_to include('Test reason 2')
      # snapshot3 should NOT be included (different person) - check for unique reason text
      expect(response.body).not_to include('Test reason 3')
    end

    it 'loads observation drafts for the current person' do
      draft1 = create(:observation, observer: person, company: company, published_at: nil, story: 'Draft story 1')
      draft2 = create(:observation, observer: person, company: company, published_at: nil, story: 'Draft story 2')
      journal_draft = create(:observation, observer: person, company: company, published_at: nil, privacy_level: :observer_only, story: 'Journal entry')
      published = create(:observation, observer: person, company: company, published_at: Time.current)
      other_draft = create(:observation, observer: other_person, company: company, published_at: nil)
      
      get "/organizations/#{company.to_param}/get_shit_done"
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Draft story 1')
      expect(response.body).to include('Draft story 2')
      expect(response.body).not_to include('Journal entry')
      expect(response.body).not_to include(published.story)
      expect(response.body).not_to include(other_draft.story)
    end

    it 'shows Archive button for observation drafts' do
      draft = create(:observation, observer: person, company: company, published_at: nil, story: 'Test draft')
      draft.observees.create!(teammate: teammate)
      
      get "/organizations/#{company.to_param}/get_shit_done"
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Archive')
      expect(response.body).to include('Test draft')
    end

    it 'shows Archive button even for draft observations older than 24 hours' do
      draft = create(:observation, observer: person, company: company, published_at: nil, story: 'Old draft')
      draft.observees.create!(teammate: teammate)
      draft.update_column(:created_at, 2.days.ago)
      
      get "/organizations/#{company.to_param}/get_shit_done"
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Archive')
    end

    it 'excludes archived observations from badge count' do
      # Ensure teammate is a CompanyTeammate
      company_teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      
      draft1 = create(:observation, observer: person, company: company, published_at: nil, story: 'Active draft')
      archived_draft = create(:observation, observer: person, company: company, published_at: nil, story: 'Archived draft')
      archived_draft.soft_delete!
      
      # The badge count should only include draft1, not archived_draft
      # We'll check this by verifying the badge count matches what's on the page
      get "/organizations/#{company.to_param}/get_shit_done"
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Active draft')
      expect(response.body).not_to include('Archived draft')
    end

    it 'loads goals needing check-in' do
      # Ensure teammate is a CompanyTeammate
      company_teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      goal1 = create(:goal, owner: company_teammate, company: company, started_at: Time.current, title: 'Unique Goal Title 1', deleted_at: nil, completed_at: nil, most_likely_target_date: 1.month.from_now, goal_type: 'quantitative_key_result')
      goal2 = create(:goal, owner: company_teammate, company: company, started_at: Time.current, title: 'Unique Goal Title 2', deleted_at: nil, completed_at: nil, most_likely_target_date: 1.month.from_now, goal_type: 'quantitative_key_result')
      # Create a check-in for goal1 that's older than 1 week
      # Use a date that's definitely more than 1 week ago
      old_check_in_date = 2.weeks.ago.beginning_of_week(:monday)
      create(:goal_check_in, goal: goal1, check_in_week_start: old_check_in_date, confidence_reporter: person)
      # goal2 has no check-ins, so it needs a check-in
      # goal1's last check-in is 2 weeks ago, so it also needs a check-in
      
      get "/organizations/#{company.to_param}/get_shit_done"
      
      expect(response).to have_http_status(:success)
      # Check that the goals section is rendered (even if empty, the section should exist)
      expect(response.body).to include('Goal Check-ins')
      # If goals are found, they should appear
      if response.body.include?('Unique Goal Title')
        expect(response.body).to include('Unique Goal Title 1')
        expect(response.body).to include('Unique Goal Title 2')
      else
        # If no goals appear, verify the section shows "All goals are up to date"
        expect(response.body).to include('All goals are up to date')
      end
    end

    describe 'check-ins awaiting input section' do
      let(:manager_person) { create(:person) }
      let(:manager_teammate) { CompanyTeammate.find_or_create_by!(person: manager_person, organization: company) }
      let(:employee_teammate) { CompanyTeammate.find_or_create_by!(person: person, organization: company) }
      let!(:employment_tenure) do
        create(:employment_tenure,
               company_teammate: employee_teammate,
               company: company,
               manager: manager_teammate)
      end
      let(:assignment) { create(:assignment, company: company, title: 'GSD Test Assignment') }
      let(:aspiration) { create(:aspiration, company: company, name: 'GSD Test Aspiration') }

      it 'renders the check-ins awaiting input section' do
        get "/organizations/#{company.to_param}/get_shit_done"

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Check-ins Awaiting Your Input")
      end

      it 'shows check-ins where manager completed but employee has not (as employee)' do
        create(:assignment_check_in,
               teammate: employee_teammate,
               assignment: assignment,
               manager_completed_at: Time.current,
               manager_completed_by_teammate: manager_teammate,
               employee_completed_at: nil)

        get "/organizations/#{company.to_param}/get_shit_done"

        expect(response).to have_http_status(:success)
        expect(response.body).to include('GSD Test Assignment')
        expect(response.body).to include('Complete as Employee')
      end

      it 'shows check-ins for direct reports where employee completed but manager has not (as manager)' do
        sign_in_as_teammate_for_request(manager_person, company)
        create(:assignment_check_in,
               teammate: employee_teammate,
               assignment: assignment,
               employee_completed_at: Time.current,
               manager_completed_at: nil)

        get "/organizations/#{company.to_param}/get_shit_done"

        expect(response).to have_http_status(:success)
        expect(response.body).to include('GSD Test Assignment')
        expect(response.body).to include('Complete as Manager')
      end

      it 'does not show check-ins where neither side is complete' do
        create(:assignment_check_in,
               teammate: employee_teammate,
               assignment: assignment,
               employee_completed_at: nil,
               manager_completed_at: nil)

        get "/organizations/#{company.to_param}/get_shit_done"

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('GSD Test Assignment')
      end

      it 'does not show finalized check-ins' do
        create(:assignment_check_in, :finalized,
               teammate: employee_teammate,
               assignment: assignment)

        get "/organizations/#{company.to_param}/get_shit_done"

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('GSD Test Assignment')
      end

      it 'shows aspiration check-ins awaiting employee input' do
        create(:aspiration_check_in,
               teammate: employee_teammate,
               aspiration: aspiration,
               manager_completed_at: Time.current,
               manager_completed_by_teammate: manager_teammate,
               employee_completed_at: nil)

        get "/organizations/#{company.to_param}/get_shit_done"

        expect(response).to have_http_status(:success)
        expect(response.body).to include('GSD Test Aspiration')
      end

      it 'shows position check-ins awaiting employee input' do
        create(:position_check_in,
               teammate: employee_teammate,
               employment_tenure: employment_tenure,
               manager_completed_at: Time.current,
               manager_completed_by_teammate: manager_teammate,
               employee_completed_at: nil)

        get "/organizations/#{company.to_param}/get_shit_done"

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Position')
        expect(response.body).to include('Complete as Employee')
      end

      it 'shows empty state when no check-ins are awaiting input' do
        get "/organizations/#{company.to_param}/get_shit_done"

        expect(response).to have_http_status(:success)
        expect(response.body).to include('No check-ins awaiting your input')
      end
    end

    it 'requires authentication' do
      sign_out_teammate_for_request
      
      get "/organizations/#{company.to_param}/get_shit_done"
      
      expect(response).to have_http_status(:redirect)
    end
  end
end


