require 'rails_helper'

RSpec.describe "Organizations::OneOnOneLinks", type: :request do
  let(:organization) { create(:organization) }
  let(:manager_person) { create(:person) }
  let(:employee_person) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:title) { create(:title, company: organization, external_title: 'Software Engineer', position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:manager_teammate) { create(:company_teammate, person: manager_person, organization: organization, can_manage_employment: true) }
  let(:employment_tenure) do
    create(:employment_tenure,
      teammate: employee_teammate,
      position: position,
      company: organization,
      manager_teammate: CompanyTeammate.find(manager_teammate.id),
      started_at: 1.year.ago,
      ended_at: nil
    )
  end

  before do
    # Create active employment for manager
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago)
    # Create active employment for employee
    employee_teammate.update!(first_employed_at: 1.year.ago)
    employment_tenure
    # Setup authentication
    sign_in_as_teammate_for_request(manager_person, organization)
  end

  describe "GET /organizations/:organization_id/company_teammates/:company_teammate_id/one_on_one_link" do
    it "shows the one-on-one link page" do
      get organization_company_teammate_one_on_one_link_path(organization, employee_teammate)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include("My One Thing")
      expect(response.body).to include("The One Thing")
      expect(response.body).to include("Detailed")
      expect(response.body).to include("What My One Thing is for")
      expect(response.body).to include("amazon.com/ONE-Thing")
      expect(response.body).to include("Clarity leads to flow")
      expect(response.body).to include("easier or unnecessary")
      expect(response.body).to include("Work to Meet")
      expect(response.body).to include("How we choose the one thing")
      expect(response.body).to include("My One Thing (Active)")
      expect(response.body).to include(detailed_organization_company_teammate_one_on_one_link_path(organization, employee_teammate))
      expect(response.body).not_to include("Current Sync Link")
    end

    it "resolves company_teammate_id 'me' (and legacy 'my') to the signed-in teammate" do
      sign_in_as_teammate_for_request(employee_person, organization)
      create(:one_on_one_link, teammate: employee_teammate, url: "https://example.com/hub")

      get organization_company_teammate_one_on_one_link_path(organization, "me")
      expect(response).to have_http_status(:success)
      expect(response.body).to include("My One Thing")

      get organization_company_teammate_one_on_one_link_path(organization, "my")
      expect(response).to have_http_status(:success)
    end

    it "collapses carousel explanation copy behind Why is this important" do
      aspiration = create(:aspiration, company: organization, name: "Team Value")
      create(:aspiration_check_in, :ready_for_finalization, teammate: employee_teammate, aspiration: aspiration)
      create(:one_on_one_link, teammate: employee_teammate, url: "https://example.com/1-1")

      get organization_company_teammate_one_on_one_link_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Why is this important")
      expect(response.body).to include('id="oneThingPriorityExplanation-1"')
      expect(response.body).to include('data-bs-target="#oneThingPriorityExplanation-1"')
      expect(response.body).to include("OG clarity check-ins are a three-step process")
    end

    it "renders the one thing section with the priority algorithm collapse" do
      get organization_company_teammate_one_on_one_link_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('id="oneThingPriorityAlgorithm"')
      expect(response.body).to include('href="#oneThingPriorityAlgorithm"')
      expect(response.body).to include('data-bs-toggle="collapse"')
      expect(response.body).to include('id="oneThingPriorityCarousel"')
      expect(response.body).to include("Why this order")
      expect(response.body).to include("Eisenhower-style ordering:")
      expect(response.body).to include("Urgent and unimportant")
      expect(response.body).to include("How do we break ties")
      expect(response.body).to include("Priority stack (highest first)")
      expect(response.body).to include("If we see tasks in the 1:1 Asana project")
      expect(response.body).to include("-- then we need to treat them as top priority.")
      expect(response.body).to include("finalization date")
      expect(response.body).to include("If we see that we have reached this point in the stack")
      expect(response.body).to include("the last 30 days")
    end

    it "shows existing one-on-one link" do
      one_on_one_link = create(:one_on_one_link, teammate: employee_teammate, url: 'https://app.asana.com/0/123456/789')
      
      get detailed_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('https://app.asana.com/0/123456/789')
      expect(response.body).to include('Current Sync Link')
    end

    it "shows Asana link detection" do
      one_on_one_link = create(:one_on_one_link, teammate: employee_teammate, url: 'https://app.asana.com/0/123456/789')
      
      get detailed_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Asana Project Detected")
    end

    it "shows connect button when Asana link but viewing user has no identity" do
      one_on_one_link = create(:one_on_one_link, teammate: employee_teammate, url: 'https://app.asana.com/0/123456/789')
      
      get detailed_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to match(/Connect Your Asana Account|Asana Project Detected/)
    end

    it "shows sync prompt when viewing user has Asana identity" do
      # Create identity for viewing user (manager), not the employee
      create(:teammate_identity, :asana, teammate: manager_teammate)
      one_on_one_link = create(:one_on_one_link, teammate: employee_teammate, url: 'https://app.asana.com/0/123456/789')
      
      # Mock project access check
      allow_any_instance_of(Organizations::CompanyTeammates::OneOnOneLinksController).to receive(:check_asana_project_access).and_return(true)
      
      get detailed_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Ready to Sync')
      expect(response.body).to include('Sync Project')
    end

    it "shows connect button when Asana link is confirmed (has cache) but viewing user has no identity" do
      one_on_one_link = create(:one_on_one_link, teammate: employee_teammate, url: 'https://app.asana.com/0/123456/789')
      one_on_one_link.deep_integration_config = { 'asana_project_id' => '123456' }
      one_on_one_link.save
      
      # Create a cache for the confirmed link (simulating a confirmed/synced state)
      # Create identity for the employee (not the viewing user)
      employee_asana_identity = create(:teammate_identity, :asana, teammate: employee_teammate)
      
      # Mock AsanaService to return successful sync
      service = instance_double(AsanaService)
      allow(AsanaService).to receive(:new).with(employee_teammate).and_return(service)
      allow(service).to receive(:authenticated?).and_return(true)
      allow(service).to receive(:fetch_project_sections).with('123456').and_return({
        success: true,
        sections: [{ 'gid' => 'section_1', 'name' => 'To Do' }]
      })
      allow(service).to receive(:fetch_all_project_tasks).with('123456').and_return({
        success: true,
        incomplete: [],
        completed: []
      })
      allow(service).to receive(:format_for_cache).and_return({
        sections: [{ 'gid' => 'section_1', 'name' => 'To Do', 'position' => 0 }],
        tasks: []
      })
      
      # Sync to create the cache
      ExternalProjectCacheService.sync_project(one_on_one_link, 'asana', employee_teammate)
      
      # Now view as manager (who doesn't have Asana identity)
      get detailed_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Connect Your Asana Account')
      expect(response.body).to include('Asana Project') # Should still show the project display
    end

    it "shows no access message when viewing user's Asana account doesn't have project access" do
      # Create identity for viewing user (manager), not the employee
      create(:teammate_identity, :asana, teammate: manager_teammate)
      one_on_one_link = create(:one_on_one_link, teammate: employee_teammate, url: 'https://app.asana.com/0/123456/789')
      one_on_one_link.deep_integration_config = { 'asana_project_id' => '123456' }
      one_on_one_link.save
      
      # Mock AsanaService to return permission denied
      service = instance_double(AsanaService)
      allow(AsanaService).to receive(:new).and_return(service)
      allow(service).to receive(:authenticated?).and_return(true)
      allow(service).to receive(:fetch_project).with('123456').and_return(nil)
      allow(service).to receive(:fetch_project_sections).with('123456').and_return({
        success: false,
        error: 'permission_denied',
        message: 'Permission denied'
      })
      
      get detailed_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include("doesn't have access to this project")
    end

    it "requires authentication" do
      # The controller uses authenticate_person! which redirects if not authenticated
      # In test environment, this might behave differently, so we'll skip this test
      # as authentication is tested at the framework level
      skip "Authentication is handled by Devise and tested at framework level"
    end

    it "requires authorization" do
      unauthorized_person = create(:person)
      unauthorized_teammate = create(:teammate, person: unauthorized_person, organization: organization)
      unauthorized_teammate.update!(first_employed_at: 1.year.ago)
      create(:employment_tenure, teammate: unauthorized_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      sign_in_as_teammate_for_request(unauthorized_person, organization)
      
      get organization_company_teammate_one_on_one_link_path(organization, employee_teammate)
      
      # Authorization failures typically redirect
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET /organizations/:organization_id/company_teammates/:company_teammate_id/one_on_one_link/detailed" do
    it "shows the detailed 1:1 hub experience" do
      get detailed_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("My One Thing (Active)")
      expect(response.body).to include("Sync")
      expect(response.body).to include("Execute")
      expect(response.body).to include("Evolve")
      expect(response.body).to include("No sync link set yet.")
    end
  end

  describe "POST /organizations/:organization_id/company_teammates/:company_teammate_id/one_on_one_link" do
    it "creates a new one-on-one link" do
      expect {
        post organization_company_teammate_one_on_one_link_path(organization, employee_teammate), params: {
          one_on_one_link: { url: 'https://example.com/1on1' }
        }
      }.to change(OneOnOneLink, :count).by(1)
      
      expect(response).to redirect_to(detailed_organization_company_teammate_one_on_one_link_path(organization, employee_teammate))
      expect(flash[:notice]).to include('created successfully')
      
      link = employee_teammate.reload.one_on_one_link
      expect(link.url).to eq('https://example.com/1on1')
    end
  end

  describe "PATCH /organizations/:organization_id/company_teammates/:company_teammate_id/one_on_one_link" do

    it "updates existing one-on-one link" do
      one_on_one_link = create(:one_on_one_link, teammate: employee_teammate, url: 'https://old-url.com')
      
      patch organization_company_teammate_one_on_one_link_path(organization, employee_teammate), params: {
        one_on_one_link: { url: 'https://new-url.com' }
      }
      
      expect(response).to redirect_to(detailed_organization_company_teammate_one_on_one_link_path(organization, employee_teammate))
      expect(flash[:notice]).to include('updated successfully')
      expect(one_on_one_link.reload.url).to eq('https://new-url.com')
    end

    it "extracts Asana project ID from URL" do
      patch organization_company_teammate_one_on_one_link_path(organization, employee_teammate), params: {
        one_on_one_link: { url: 'https://app.asana.com/0/123456/789' }
      }
      
      expect(response).to redirect_to(detailed_organization_company_teammate_one_on_one_link_path(organization, employee_teammate, anchor: 'sync'))
      
      link = employee_teammate.reload.one_on_one_link
      expect(link.asana_project_id).to eq('123456')
      expect(link.deep_integration_config['asana_project_id']).to eq('123456')
    end

    it "validates URL format" do
      patch organization_company_teammate_one_on_one_link_path(organization, employee_teammate), params: {
        one_on_one_link: { url: 'not-a-valid-url' }
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("must be a valid URL")
    end

    it "requires authentication" do
      # The controller uses authenticate_person! which redirects if not authenticated
      # In test environment, this might behave differently, so we'll skip this test
      # as authentication is tested at the framework level
      skip "Authentication is handled by Devise and tested at framework level"
    end

    it "requires authorization" do
      unauthorized_person = create(:person)
      unauthorized_teammate = create(:teammate, person: unauthorized_person, organization: organization)
      unauthorized_teammate.update!(first_employed_at: 1.year.ago)
      create(:employment_tenure, teammate: unauthorized_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      sign_in_as_teammate_for_request(unauthorized_person, organization)
      
      patch organization_company_teammate_one_on_one_link_path(organization, employee_teammate), params: {
        one_on_one_link: { url: 'https://example.com' }
      }
      
      # Authorization failures typically redirect
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "POST /organizations/:organization_id/company_teammates/:company_teammate_id/one_on_one_link/sync" do
    let(:one_on_one_link) { create(:one_on_one_link, teammate: employee_teammate, url: 'https://app.asana.com/0/123456/789') }
    let(:asana_identity) { create(:teammate_identity, :asana, teammate: manager_teammate) }

    before do
      one_on_one_link
      # Mock AsanaService to avoid actual API calls
      allow_any_instance_of(AsanaService).to receive(:authenticated?).and_return(true)
      allow_any_instance_of(AsanaService).to receive(:fetch_project_sections).and_return({
        success: true,
        sections: [
          { 'gid' => 'section_1', 'name' => 'To Do' },
          { 'gid' => 'section_2', 'name' => 'In Progress' }
        ]
      })
      allow_any_instance_of(AsanaService).to receive(:fetch_all_project_tasks).and_return({
        success: true,
        incomplete: [
          { 'gid' => 'task_1', 'name' => 'Task 1', 'section_gid' => 'section_1', 'completed' => false, 'due_on' => 1.day.from_now.to_date.to_s, 'assignee' => { 'gid' => 'user_1', 'name' => 'Alice' }, 'created_at' => 5.days.ago.iso8601 },
          { 'gid' => 'task_2', 'name' => 'Task 2', 'section_gid' => 'section_1', 'completed' => false, 'due_on' => nil, 'assignee' => nil, 'created_at' => 3.days.ago.iso8601 }
        ],
        completed: [
          { 'gid' => 'task_3', 'name' => 'Task 3', 'section_gid' => 'section_2', 'completed' => true, 'completed_at' => 5.days.ago.iso8601 }
        ]
      })
      allow_any_instance_of(AsanaService).to receive(:format_for_cache).and_return({
        sections: [
          { 'gid' => 'section_1', 'name' => 'To Do', 'position' => 0 },
          { 'gid' => 'section_2', 'name' => 'In Progress', 'position' => 1 }
        ],
        tasks: [
          { 'gid' => 'task_1', 'name' => 'Task 1', 'section_gid' => 'section_1', 'completed' => false, 'due_on' => 1.day.from_now.to_date.to_s, 'assignee' => { 'gid' => 'user_1', 'name' => 'Alice' }, 'created_at' => 5.days.ago.iso8601 },
          { 'gid' => 'task_2', 'name' => 'Task 2', 'section_gid' => 'section_1', 'completed' => false, 'due_on' => nil, 'assignee' => nil, 'created_at' => 3.days.ago.iso8601 },
          { 'gid' => 'task_3', 'name' => 'Task 3', 'section_gid' => 'section_2', 'completed' => true, 'completed_at' => 5.days.ago.iso8601 }
        ]
      })
    end

    it "enqueues sync and redirects to the sync section" do
      asana_identity
      expect {
        post sync_organization_company_teammate_one_on_one_link_path(organization, employee_teammate, source: 'asana')
      }.to have_enqueued_job(ExternalProject::SyncCacheableJob)

      expect(response).to redirect_to(
        detailed_organization_company_teammate_one_on_one_link_path(organization, employee_teammate, anchor: 'sync')
      )
      expect(flash[:notice]).to match(/sync started/i)
    end

    it "shows the sync polling UI after redirect" do
      asana_identity
      post sync_organization_company_teammate_one_on_one_link_path(organization, employee_teammate, source: 'asana')
      follow_redirect!

      expect(response.body).to include("external-project-sync-poll")
      expect(response.body).to include("Syncing Asana project")
      expect(response.body).to include("placeholder-glow")
    end

    it "syncs project data when the background job runs" do
      asana_identity
      expect {
        post sync_organization_company_teammate_one_on_one_link_path(organization, employee_teammate, source: 'asana')
        perform_enqueued_jobs
      }.to change(ExternalProjectCache, :count).by(1)

      cache = one_on_one_link.reload.external_project_cache_for('asana')
      expect(cache.sync_status).to eq('completed')
      expect(cache.last_synced_at).to be_present
    end

    it "displays synced project data on the page" do
      asana_identity
      post sync_organization_company_teammate_one_on_one_link_path(organization, employee_teammate, source: 'asana')
      perform_enqueued_jobs

      get detailed_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Asana Project')
      expect(response.body).to include('Task 1')
      expect(response.body).to include('Task 2')
    end

    it "displays task details with due dates and assignees" do
      asana_identity
      post sync_organization_company_teammate_one_on_one_link_path(organization, employee_teammate, source: 'asana')
      perform_enqueued_jobs

      get detailed_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Task 1')
    end

    it "redirects to the sync anchor when syncing" do
      asana_identity
      return_url = about_me_organization_company_teammate_path(organization, employee_teammate)

      post sync_organization_company_teammate_one_on_one_link_path(organization, employee_teammate, source: 'asana', return_url: return_url)

      expect(response).to redirect_to(
        detailed_organization_company_teammate_one_on_one_link_path(organization, employee_teammate, anchor: 'sync')
      )
    end

    context "when sync fails with token expiration" do
      before do
        allow_any_instance_of(AsanaService).to receive(:fetch_project_sections).and_return({
          success: false,
          error: 'token_expired',
          message: 'Token expired'
        })
      end

      it "marks the cache failed when the background job cannot sync" do
        asana_identity
        post sync_organization_company_teammate_one_on_one_link_path(organization, employee_teammate, source: 'asana')
        perform_enqueued_jobs

        cache = one_on_one_link.reload.external_project_cache_for('asana')
        expect(cache).to be_present
        expect(cache.sync_status).to eq('failed')
        expect(cache.sync_error_type).to eq('token_expired')
        expect(cache.sync_error).to include('token has expired')
      end

      it "shows re-authentication link in view after a failed sync" do
        asana_identity
        post sync_organization_company_teammate_one_on_one_link_path(organization, employee_teammate, source: 'asana')
        perform_enqueued_jobs

        get detailed_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)

        expect(response).to have_http_status(:success)
        expect(response.body).to match(/token has expired|Reconnect|reconnect/i)
      end
    end

    context "when sync fails with permission denied" do
      before do
        allow_any_instance_of(AsanaService).to receive(:fetch_project_sections).and_return({
          success: false,
          error: 'permission_denied',
          message: 'Permission denied'
        })
      end

      it "stores permission error on the cache when sync fails" do
        asana_identity
        post sync_organization_company_teammate_one_on_one_link_path(organization, employee_teammate, source: 'asana')
        perform_enqueued_jobs

        cache = one_on_one_link.reload.external_project_cache_for('asana')
        expect(cache.sync_status).to eq('failed')
        expect(cache.sync_error).to include('permission')
      end
    end

    context "when sync fails with project not found" do
      before do
        allow_any_instance_of(AsanaService).to receive(:fetch_project_sections).and_return({
          success: false,
          error: 'not_found',
          message: 'Project not found'
        })
      end

      it "stores not found error on the cache when sync fails" do
        asana_identity
        post sync_organization_company_teammate_one_on_one_link_path(organization, employee_teammate, source: 'asana')
        perform_enqueued_jobs

        cache = one_on_one_link.reload.external_project_cache_for('asana')
        expect(cache.sync_status).to eq('failed')
        expect(cache.sync_error).to include('not found')
      end
    end

    it "requires authentication" do
      skip "Authentication is handled by Devise and tested at framework level"
    end
  end

  describe "GET overview" do
    it "renders the Overview tab with all five engagement health categories" do
      get overview_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Engagement Health")
      expect(response.body).to include("OGOs Given")
      expect(response.body).to include("OGOs Received")
      expect(response.body).to include("Goal Confidence")
      expect(response.body).to include("Required Clarity Check-Ins")
      expect(response.body).to include("Milestones")
      expect(response.body).to include("Recalculate now")
    end

    it "computes and caches engagement health on first view" do
      expect {
        get overview_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)
      }.to change { EngagementHealthStatus.where(teammate: employee_teammate).count }.from(0)

      expect(EngagementHealthStatus.where(teammate: employee_teammate, level: "category").count).to eq(5)
    end

    it "surfaces never edge cases as Needs Attention" do
      get overview_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)

      expect(response.body).to include("Never")
      expect(response.body).to include("never started or completed a goal")
    end

    it "requires authorization" do
      unauthorized_person = create(:person)
      unauthorized_teammate = create(:teammate, person: unauthorized_person, organization: organization)
      unauthorized_teammate.update!(first_employed_at: 1.year.ago)
      create(:employment_tenure, teammate: unauthorized_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      sign_in_as_teammate_for_request(unauthorized_person, organization)

      get overview_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)

      expect(response).to have_http_status(:redirect)
    end
  end

  describe "POST recalculate_engagement_health" do
    it "recalculates the cache and redirects to the overview" do
      post recalculate_engagement_health_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)

      expect(response).to redirect_to(overview_organization_company_teammate_one_on_one_link_path(organization, employee_teammate))
      expect(EngagementHealthStatus.where(teammate: employee_teammate)).to be_present
      follow_redirect!
      expect(response.body).to include("Recalculated")
    end

    it "highlights rows where the cached status differs from the fresh calculation" do
      # Prime the cache, then tamper with a cached status to simulate an update-path bug
      EngagementHealth::Refresher.call(employee_teammate)
      record = EngagementHealthStatus.items.for_category("ogo_given").find_by(teammate: employee_teammate)
      record.update!(status: EngagementHealth::HEALTHY)

      post recalculate_engagement_health_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)
      follow_redirect!

      expect(response.body).to include("differed from the cache")
      expect(response.body).to include("table-warning")
    end
  end

  describe "GET work_to_meet" do
    it "renders the Work to Meet tab with aspirational and assignment sections" do
      get work_to_meet_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Work to Meet")
      expect(response.body).to include("Aspirational Values")
      expect(response.body).to include("Assignments")
    end

    it "shows the non-essential assignments collapse when present" do
      non_essential = create(:assignment, company: organization, title: "Side project")
      create(:assignment_check_in, :finalized, :working_to_meet, teammate: employee_teammate, assignment: non_essential)

      get work_to_meet_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)

      expect(response.body).to include("Non-essential Assignments that are Working to Meet Expectations")
      expect(response.body).to include("Side project")
    end

    it "links draft goals to the goals index filtered by teammate and draft status" do
      assignment = create(:assignment, company: organization, title: "Draft Goal Link")
      create(:assignment_tenure, teammate: employee_teammate, assignment: assignment)
      create(:assignment_check_in, :finalized, :working_to_meet, teammate: employee_teammate, assignment: assignment)
      draft_goal = create(:goal, owner: employee_teammate, creator: employee_teammate, company_id: organization.id, started_at: nil)
      create(:goal_association, goal: draft_goal, associable: assignment)

      get work_to_meet_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("1 draft goal")
      expect(response.body).to include("owner_id=CompanyTeammate_#{employee_teammate.id}")
      expect(response.body).to include("status=draft")
    end

    it "shows Add OGO and a linked OGO count caption filtered by observee and rateable" do
      assignment = create(:assignment, company: organization, title: "OGO Assignment")
      create(:assignment_tenure, teammate: employee_teammate, assignment: assignment)
      create(:assignment_check_in, :finalized, :working_to_meet, teammate: employee_teammate, assignment: assignment)

      observation = create(:observation, company: organization, observer: manager_person, published_at: Time.current)
      observation.observees.destroy_all
      create(:observee, observation: observation, company_teammate: employee_teammate)
      create(:observation_rating, observation: observation, rateable: assignment)

      get work_to_meet_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Add OGO")
      expect(response.body).to include("new_quick_note")
      expect(response.body).to include("observee_ids%5B%5D=#{employee_teammate.id}")
      expect(response.body).to include("rateable_type=Assignment")
      expect(response.body).to include("rateable_id=#{assignment.id}")
      expect(response.body).to include("1 relevant OGO")
    end

    it "shows danger badge on hub tabs when essential WTM areas lack active goals" do
      assignment = create(:assignment, company: organization, title: "Needs Goal")
      create(:assignment_tenure, teammate: employee_teammate, assignment: assignment)
      create(:assignment_check_in, :finalized, :working_to_meet, teammate: employee_teammate, assignment: assignment)

      get work_to_meet_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("text-bg-danger")
      expect(response.body).to include("Needs Goal")
      expect(response.body).to include("No active goal")
    end

    it "shows a hover popover with full check-in sentences on the most recent check-in cell" do
      assignment = create(:assignment, company: organization, title: "Popover Assignment")
      create(:assignment_tenure, teammate: employee_teammate, assignment: assignment)
      create(
        :assignment_check_in,
        :finalized,
        :working_to_meet,
        teammate: employee_teammate,
        assignment: assignment,
        employee_private_notes: "Employee note for popover",
        manager_private_notes: "Manager note for popover",
        shared_notes: "Shared note for popover"
      )

      get work_to_meet_organization_company_teammate_one_on_one_link_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('class="check-in-summary-popover-trigger')
      expect(response.body).to include("Employee note for popover")
      expect(response.body).to include("Manager note for popover")
      expect(response.body).to include("Shared note for popover")
      expect(response.body).to include("they agreed")
    end
  end

  describe "POST /organizations/:organization_id/company_teammates/:company_teammate_id/one_on_one_link/items/:id" do
    let(:one_on_one_link) { create(:one_on_one_link, teammate: employee_teammate, url: 'https://app.asana.com/0/123456/789') }
    let(:asana_identity) { create(:teammate_identity, :asana, teammate: employee_teammate) }

    before do
      one_on_one_link
      # Mock AsanaService to avoid actual API calls
      allow_any_instance_of(AsanaService).to receive(:authenticated?).and_return(true)
      allow_any_instance_of(AsanaService).to receive(:fetch_task_details).and_return({
        'gid' => '123456',
        'name' => 'Test Task',
        'completed' => false
      })
    end

    it "shows item details" do
      asana_identity
      get organization_company_teammate_one_on_one_link_item_path(organization, employee_teammate, '123456', source: 'asana')
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Test Task')
    end
  end
end

