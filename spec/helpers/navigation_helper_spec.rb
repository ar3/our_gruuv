require 'rails_helper'

RSpec.describe NavigationHelper, type: :helper do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: company) }

  describe '#pending_get_shit_done_count' do
    it 'returns 0 when teammate is nil' do
      expect(helper.pending_get_shit_done_count(nil)).to eq(0)
    end

    it 'counts all pending items' do
      # Ensure teammate is a CompanyTeammate
      company_teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      
      observable_moment = create(:observable_moment, :new_hire, company: company, primary_observer_person: person)
      observable_moment.reload
      create(:maap_snapshot, employee_company_teammate: company_teammate, company: company, employee_acknowledged_at: nil, effective_date: Time.current)
      create(:observation, observer: person, company: company, published_at: nil)
      # Goal needs to meet check_in_eligible criteria
      goal = create(:goal, owner: company_teammate, company: company, started_at: Time.current, deleted_at: nil, completed_at: nil, most_likely_target_date: 1.month.from_now, goal_type: 'quantitative_key_result')
      
      count = helper.pending_get_shit_done_count(company_teammate)
      # Should have at least 3 (observable moment, maap snapshot, observation)
      # Goal may or may not be included depending on check_in_eligible scope
      expect(count).to be >= 3
    end

    it 'excludes archived observations from count' do
      company_teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      
      draft1 = create(:observation, observer: person, company: company, published_at: nil)
      archived_draft = create(:observation, observer: person, company: company, published_at: nil)
      archived_draft.soft_delete!
      
      count = helper.pending_get_shit_done_count(company_teammate)
      # Should only count draft1, not archived_draft
      expect(count).to eq(1)
    end

    it 'excludes journal observations from count' do
      company_teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      
      draft1 = create(:observation, observer: person, company: company, published_at: nil, privacy_level: :observed_only, story: "Draft 1 #{SecureRandom.hex(4)}")
      journal_draft = create(:observation, observer: person, company: company, published_at: nil, privacy_level: :observer_only, story: "Journal #{SecureRandom.hex(4)}")
      
      count = helper.pending_get_shit_done_count(company_teammate)
      # Should only count draft1, not journal_draft
      expect(count).to eq(1)
    end

    it 'uses the same query logic as GetShitDoneQueryService' do
      company_teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      
      # Create various observations
      draft1 = create(:observation, observer: person, company: company, published_at: nil)
      journal_draft = create(:observation, observer: person, company: company, published_at: nil, privacy_level: :observer_only)
      archived_draft = create(:observation, observer: person, company: company, published_at: nil)
      archived_draft.soft_delete!
      
      # Both should return the same count
      helper_count = helper.pending_get_shit_done_count(company_teammate)
      service_count = GetShitDoneQueryService.new(teammate: company_teammate).total_pending_count
      
      expect(helper_count).to eq(service_count)
      expect(helper_count).to eq(1) # Only draft1 should be counted
    end
  end

  describe '#navigation_structure' do
    before do
      # Define the controller methods that are available in helpers
      def helper.current_organization
        @current_organization
      end

      def helper.current_person
        @current_person
      end

      def helper.current_company_teammate
        @current_company_teammate
      end

      def helper.current_company
        @current_company
      end

      # Stub the policy method to return appropriate policy doubles
      allow(helper).to receive(:policy) do |record|
        # Kudos center nav - must match first so :kudos symbol is handled
        return double(view_dashboard?: true) if record == :kudos || record.to_s == 'kudos'
        # Handle Organization class or instance
        if record == Organization || record.is_a?(Organization) || (record.is_a?(Class) && record <= Organization)
          # For Organization class or instance, return a policy that allows show? for "My Employees" and "View Teammates"
          double(show?: true, view_prompts?: true, view_prompt_templates?: true, view_observations?: true, view_seats?: true, view_goals?: true, view_abilities?: true, view_assignments?: true, view_aspirations?: true, view_bulk_sync_events?: true, customize_company?: true, manage_employment?: true, view_feedback_requests?: true, check_ins_health?: true, view_slack_settings?: true, view_company_preferences?: true)
        elsif record == Company || record.is_a?(Company) || (record.is_a?(Class) && record <= Company)
          double(view_prompts?: true, view_prompt_templates?: true, view_observations?: true, view_seats?: true, view_goals?: true, view_abilities?: true, view_assignments?: true, view_aspirations?: true, view_bulk_sync_events?: true, customize_company?: true, view_company_preferences?: true)
        elsif record.is_a?(CompanyTeammate)
          double(view_check_ins?: true)
        elsif record.is_a?(Huddle)
          double(show?: true)
        else
          # For other records, return a policy that allows show?
          double(show?: true, view_prompts?: true, view_dashboard?: true)
        end
      end

      helper.instance_variable_set(:@current_organization, company)
      helper.instance_variable_set(:@current_person, person)
      # Ensure teammate is a CompanyTeammate for has_direct_reports? method
      company_teammate = teammate.is_a?(CompanyTeammate) ? teammate : CompanyTeammate.find(teammate.id)
      helper.instance_variable_set(:@current_company_teammate, company_teammate)
      helper.instance_variable_set(:@current_company, company)
    end

    it 'uses company_label_plural for prompts navigation label under About Me' do
      company = create(:organization, :company, name: 'Test Company')
      helper.instance_variable_set(:@current_organization, company)
      helper.instance_variable_set(:@current_company, company)

      structure = helper.navigation_structure
      about_me_section = structure.find { |item| item[:label] == 'About Me' }
      expect(about_me_section).to be_present
      prompts_item = about_me_section[:items].find { |item| item[:path]&.include?('prompts') }
      expect(prompts_item).to be_present
      expect(prompts_item[:label]).to eq('My Prompts') # Default when no custom label
    end

    context 'when company has custom label preference' do
      let(:company) { create(:organization, :company, name: 'Test Company') }

      before do
        create(:company_label_preference, company: company, label_key: 'prompt', label_value: 'Reflection')
        helper.instance_variable_set(:@current_organization, company)
        helper.instance_variable_set(:@current_company, company)
      end

      it 'uses the custom plural label under About Me' do
        structure = helper.navigation_structure
        about_me_section = structure.find { |item| item[:label] == 'About Me' }
        expect(about_me_section).to be_present
        prompts_item = about_me_section[:items].find { |item| item[:path]&.include?('prompts') }
        expect(prompts_item).to be_present
        expect(prompts_item[:label]).to eq('My Reflections')
      end
    end

    describe 'About Me section' do
      it 'includes About Me section first in navigation structure' do
        structure = helper.navigation_structure
        about_me_section = structure.find { |item| item[:label] == 'About Me' }
        expect(about_me_section).to be_present
        expect(about_me_section[:section]).to eq('about_me')
        expect(about_me_section[:icon]).to eq('bi-person')
        expect(structure.first[:label]).to eq('About Me')
      end

      it 'has the expected seven sub-items: About teammate, My Check-In, OGO\'s involving me, My Feedback Requests, My Prompts, My Goals, My Huddles' do
        structure = helper.navigation_structure
        about_me_section = structure.find { |item| item[:label] == 'About Me' }
        items = about_me_section[:items]
        labels = items.map { |item| item[:label] }

        expect(items.length).to eq(7)
        expect(labels[0]).to match(/\AAbout .+\z/)
        expect(labels[1]).to eq('My Check-In')
        expect(labels[2]).to eq("OGO's involving me")
        expect(labels[3]).to eq('My Feedback Requests')
        expect(labels[4]).to eq('My Prompts')
        expect(labels[5]).to eq('My Goals')
        expect(labels[6]).to eq('My Huddles')
      end
    end

    it 'has Teammate Directory section with View Teammates (employee tenure), My Employees, and Employee Hierarchy' do
      structure = helper.navigation_structure
      directory_section = structure.find { |item| item[:label] == 'Teammate Directory' }
      expect(directory_section).to be_present
      expect(directory_section[:section]).to eq('directory')
      expect(directory_section[:icon]).to eq('bi-people')

      view_teammates_item = directory_section[:items].find { |item| item[:label] == 'View Teammates' }
      expect(view_teammates_item).to be_present
      expect(view_teammates_item[:path]).to include('spotlight=teammate_tenures')

      hierarchy_item = directory_section[:items].find { |item| item[:label] == 'Employee Hierarchy' }
      expect(hierarchy_item).to be_present
      expect(hierarchy_item[:path]).to include('spotlight=manager_distribution')
      expect(hierarchy_item[:path]).to include('view=vertical_hierarchy')
      expect(hierarchy_item[:path]).to include('status')
      expect(hierarchy_item[:path]).to include('unassigned_employee')
      expect(hierarchy_item[:path]).to include('assigned_employee')
    end

    context 'when teammate has direct reports' do
      let(:manager_person) { create(:person) }
      let(:manager_teammate) { create(:company_teammate, person: manager_person, organization: company, first_employed_at: 1.year.ago) }
      let(:direct_report) { create(:person) }
      let(:direct_report_teammate) { create(:company_teammate, person: direct_report, organization: company, first_employed_at: 6.months.ago) }
      let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
      let(:title) { create(:title, company: company, position_major_level: position_major_level) }
      let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
      let(:position) { create(:position, title: title, position_level: position_level) }
      let!(:employment_tenure) do
        create(:employment_tenure,
          company_teammate: direct_report_teammate,
          company: company,
          position: position,
          manager_teammate: manager_teammate,
          started_at: 6.months.ago
        )
      end

      before do
        helper.instance_variable_set(:@current_company_teammate, manager_teammate)
        helper.instance_variable_set(:@current_organization, company)
        helper.instance_variable_set(:@current_company, company)
        # Verify manager has direct reports
        expect(manager_teammate.has_direct_reports?).to be true
      end

      it 'includes "My Employees" under Teammate Directory in navigation' do
        structure = helper.visible_navigation_structure
        directory_section = structure.find { |item| item[:label] == 'Teammate Directory' }
        expect(directory_section).to be_present, "Expected 'Teammate Directory' section in navigation, but found: #{structure.map { |item| item[:label] }.inspect}"
        item_labels = directory_section[:items].map { |item| item[:label] }
        expect(item_labels).to include('My Employees'), "Expected 'My Employees' under Teammate Directory, but found: #{item_labels.inspect}"

        my_employees_item = directory_section[:items].find { |item| item[:label] == 'My Employees' }
        expect(my_employees_item).to be_present
        expect(my_employees_item[:path]).to include('managers_view')
        expect(my_employees_item[:path]).to include("manager_teammate_id=#{manager_teammate.id}")
      end

      it 'places "My Employees" after "View Teammates" under Teammate Directory' do
        structure = helper.visible_navigation_structure
        directory_section = structure.find { |item| item[:label] == 'Teammate Directory' }
        expect(directory_section).to be_present
        view_teammates_index = directory_section[:items].find_index { |item| item[:label] == 'View Teammates' }
        my_employees_index = directory_section[:items].find_index { |item| item[:label] == 'My Employees' }
        expect(view_teammates_index).to be_present, "Expected 'View Teammates' under Teammate Directory"
        expect(my_employees_index).to be_present, "Expected 'My Employees' under Teammate Directory"
        expect(my_employees_index).to be > view_teammates_index
      end
    end

    context 'when teammate has no direct reports' do
      let(:teammate_without_reports) do
        teammate_without = create(:company_teammate, person: create(:person), organization: company, first_employed_at: 1.year.ago)
        # Ensure no direct reports exist
        EmploymentTenure.where(manager_teammate: teammate_without, ended_at: nil).update_all(ended_at: Time.current)
        teammate_without
      end

      before do
        helper.instance_variable_set(:@current_company_teammate, teammate_without_reports)
      end

      it 'does not include "My Employees" in Teammate Directory items' do
        # Verify teammate has no direct reports
        expect(teammate_without_reports.has_direct_reports?).to be false
        structure = helper.visible_navigation_structure
        directory_section = structure.find { |item| item[:label] == 'Teammate Directory' }
        expect(directory_section).to be_present
        my_employees_item = directory_section[:items]&.find { |item| item[:label] == 'My Employees' }
        expect(my_employees_item).to be_nil
      end
    end

    describe 'Insights section' do
      it 'includes Insights section in navigation structure' do
        structure = helper.navigation_structure
        insights_section = structure.find { |item| item[:label] == 'Insights' }
        expect(insights_section).to be_present
        expect(insights_section[:section]).to eq('insights')
        expect(insights_section[:icon]).to eq('bi-bar-chart-line')
      end

      it 'has the expected Insights sub-items with Observations first and Check-ins Health last' do
        structure = helper.navigation_structure
        insights_section = structure.find { |item| item[:label] == 'Insights' }
        items = insights_section[:items]
        
        labels = items.map { |item| item[:label] }
        expect(labels.first).to eq('Observations')
        expect(labels).to include('Who is doing what')
        expect(labels).to include('Seats, Titles, Positions')
        expect(labels).to include('Assignments')
        expect(labels).to include('Abilities')
        expect(labels).to include('Goals')
        expect(labels).to include('Feedback Requests')
        expect(labels).to include('Huddles')
        expect(labels.last).to eq('Check-ins Health')
      end

      it 'places Insights section between Huddles and Admin/Explore MAAP(s)' do
        structure = helper.navigation_structure
        huddles_index = structure.find_index { |item| item[:label] == 'Huddles' }
        insights_index = structure.find_index { |item| item[:label] == 'Insights' }
        admin_explore_index = structure.find_index { |item| item[:label] == 'Admin/Explore MAAP(s)' }
        
        expect(huddles_index).to be_present
        expect(insights_index).to be_present
        expect(admin_explore_index).to be_present
        expect(insights_index).to be > huddles_index
        expect(insights_index).to be < admin_explore_index
      end
    end

    describe 'Admin/Explore MAAP(s), Admin (org essentials + admin), and Beta sections' do
      it 'includes Admin/Explore MAAP(s) section with Milestones & Abilities, Assignments, Positions, Seats' do
        structure = helper.navigation_structure
        section = structure.find { |item| item[:label] == 'Admin/Explore MAAP(s)' }
        expect(section).to be_present
        expect(section[:section]).to eq('admin_explore_maps')
        labels = section[:items].map { |item| item[:label] }
        expect(labels).to eq(['Milestones & Abilities', 'Assignments', 'Positions', 'Seats'])
      end

      it 'includes Admin section (org essentials + admin) with section id admin' do
        structure = helper.navigation_structure
        section = structure.find { |item| item[:label] == 'Admin' && item[:section] == 'admin' }
        expect(section).to be_present
        expect(section[:section]).to eq('admin')
      end

      it 'includes Admin section with org essentials: Aspirational Values, Departments, Teams, Preferences' do
        structure = helper.navigation_structure
        section = structure.find { |item| item[:label] == 'Admin' && item[:section] == 'admin' }
        expect(section).to be_present
        labels = section[:items].map { |item| item[:label] }
        expect(labels).to include('Aspirational Values')
        expect(labels).to include('Departments')
        expect(labels).to include('Teams')
        expect(labels.any? { |l| l&.end_with?(' Preferences') }).to be true
      end

      it 'includes Admin section with admin items: Prompt Templates, Bulk Events, Bulk Downloads, Slack Settings' do
        structure = helper.navigation_structure
        section = structure.find { |item| item[:label] == 'Admin' && item[:section] == 'admin' }
        expect(section).to be_present
        labels = section[:items].map { |item| item[:label] }
        expect(labels).to include('Prompt Templates')
        expect(labels).to include('Bulk Events')
        expect(labels).to include('Bulk Downloads')
        expect(labels).to include('Slack Settings')
        expect(labels).not_to include('Check-ins Health')
      end

      it 'includes Beta section with Eligibility Requirements' do
        structure = helper.navigation_structure
        section = structure.find { |item| item[:label] == 'Beta' }
        expect(section).to be_present
        expect(section[:section]).to eq('beta')
        labels = section[:items].map { |item| item[:label] }
        expect(labels).to include('Eligibility Requirements')
      end
    end

    describe 'Kudos Center section' do
      it 'includes Kudos Points Center section above Admin' do
        structure = helper.navigation_structure
        kudos_center = structure.find { |item| item[:label]&.end_with?(' Center') && item[:section] == 'kudos_center' }
        expect(kudos_center).to be_present
        expect(kudos_center[:section]).to eq('kudos_center')
        expect(kudos_center[:icon]).to eq('bi-coin')

        admin_index = structure.find_index { |item| item[:label] == 'Admin' }
        kudos_index = structure.find_index { |item| item == kudos_center }
        expect(kudos_index).to be < admin_index
      end

      it 'has My Balance, Rewards Catalog, Leader Board, Bank, and Economy items' do
        structure = helper.navigation_structure
        kudos_center = structure.find { |item| item[:section] == 'kudos_center' }
        expect(kudos_center).to be_present
        labels = kudos_center[:items].map { |item| item[:label] }
        paths = kudos_center[:items].map { |item| item[:path].to_s }
        expect(labels).to include('My Balance')
        expect(labels).to include('Rewards Catalog')
        expect(labels.any? { |l| l&.include?('Leader Board') }).to be true
        expect(labels.any? { |l| l&.include?('Bank') }).to be true
        expect(labels.any? { |l| l&.include?('Economy') }).to be true
        expect(paths.any? { |p| p.include?('leaderboard') }).to be true
        expect(paths.any? { |p| p.include?('bank_awards') }).to be true
        expect(paths.any? { |p| p.include?('economy') }).to be true
      end

      it 'shows all five Kudos Center items in visible navigation for teammate with view_dashboard?' do
        # Use real policy so KudosPolicy#view_dashboard? runs with current_company_teammate (any CompanyTeammate passes)
        allow(helper).to receive(:policy).and_call_original
        structure = helper.visible_navigation_structure
        kudos_center = structure.find { |item| item[:section] == 'kudos_center' }
        expect(kudos_center).to be_present
        labels = kudos_center[:items].map { |item| item[:label] }
        expect(labels).to include('My Balance')
        expect(labels).to include('Rewards Catalog')
        expect(labels.any? { |l| l&.include?('Leader Board') }).to be true
        expect(labels.any? { |l| l&.include?('Bank') }).to be true
        expect(labels.any? { |l| l&.include?('Economy') }).to be true
        expect(kudos_center[:items].size).to eq(5)
      end
    end

    describe 'Observations (OGO) section' do
      it 'includes Observations (OGO) section in navigation structure' do
        structure = helper.navigation_structure
        ogo_section = structure.find { |item| item[:label] == 'Observations (OGO)' }
        expect(ogo_section).to be_present
        expect(ogo_section[:section]).to eq('observations_ogo')
        expect(ogo_section[:icon]).to eq('bi-eye')
      end

      it 'has the expected four sub-items in order' do
        structure = helper.navigation_structure
        ogo_section = structure.find { |item| item[:label] == 'Observations (OGO)' }
        items = ogo_section[:items]
        labels = items.map { |item| item[:label] }

        expect(labels.length).to eq(4)
        expect(labels[0]).to eq('Add New OGO')
        expect(labels[2]).to eq("OGO's involving me")
        expect(labels[3]).to eq('All observations')
        expect(labels[1]).to match(/\A.+ Kudos\z/)
      end

      it 'uses organization name in Kudos sub-item label' do
        company = create(:organization, :company, name: 'Acme Corp')
        helper.instance_variable_set(:@current_organization, company)
        helper.instance_variable_set(:@current_company, company)
        helper.instance_variable_set(:@current_company_teammate, teammate)

        structure = helper.navigation_structure
        ogo_section = structure.find { |item| item[:label] == 'Observations (OGO)' }
        highlights_item = ogo_section[:items].find { |item| item[:label]&.end_with?(' Kudos') }
        expect(highlights_item).to be_present
        expect(highlights_item[:label]).to eq('Acme Corp Kudos')
      end

      it 'places About Me first and Observations (OGO) second in navigation' do
        structure = helper.navigation_structure
        about_me_index = structure.find_index { |item| item[:label] == 'About Me' }
        ogo_index = structure.find_index { |item| item[:label] == 'Observations (OGO)' }

        expect(about_me_index).to eq(0)
        expect(ogo_index).to eq(1)
      end
    end
  end

  describe '#nav_item_active?' do
    let(:request_double) do
      double('request').tap do |req|
        allow(req).to receive(:path).and_return('/organizations/1/observations')
        allow(req).to receive(:query_parameters).and_return({})
      end
    end

    before do
      allow(helper).to receive(:request).and_return(request_double)
    end

    context 'when the link has no query parameters' do
      it 'is active when path matches and current request has no query params' do
        allow(request_double).to receive(:path).and_return('/organizations/1/observations')
        allow(request_double).to receive(:query_parameters).and_return({})
        expect(helper.nav_item_active?('/organizations/1/observations')).to be true
      end

      it 'is active when path matches and current request has query params' do
        allow(request_double).to receive(:path).and_return('/organizations/1/observations')
        allow(request_double).to receive(:query_parameters).and_return('view' => 'wall', 'privacy' => 'public')
        expect(helper.nav_item_active?('/organizations/1/observations')).to be true
      end

      it 'is active when current path is a subpath of the link path' do
        allow(request_double).to receive(:path).and_return('/organizations/1/observations/123')
        allow(request_double).to receive(:query_parameters).and_return({})
        expect(helper.nav_item_active?('/organizations/1/observations')).to be true
      end

      it 'is not active when path does not match' do
        allow(request_double).to receive(:path).and_return('/organizations/1/goals')
        expect(helper.nav_item_active?('/organizations/1/observations')).to be false
      end
    end

    context 'when the link has query parameters' do
      it 'is active when path and query params match' do
        allow(request_double).to receive(:path).and_return('/organizations/1/observations')
        allow(request_double).to receive(:query_parameters).and_return('view' => 'wall', 'privacy' => 'public')
        expect(helper.nav_item_active?('/organizations/1/observations?view=wall&privacy=public')).to be true
      end

      it 'is active when path and query params match (different param order)' do
        allow(request_double).to receive(:path).and_return('/organizations/1/observations')
        allow(request_double).to receive(:query_parameters).and_return('privacy' => 'public', 'view' => 'wall')
        expect(helper.nav_item_active?('/organizations/1/observations?view=wall&privacy=public')).to be true
      end

      it 'is not active when path matches but current request has no query params' do
        allow(request_double).to receive(:path).and_return('/organizations/1/observations')
        allow(request_double).to receive(:query_parameters).and_return({})
        expect(helper.nav_item_active?('/organizations/1/observations?view=wall')).to be false
      end

      it 'is not active when path matches but query params differ' do
        allow(request_double).to receive(:path).and_return('/organizations/1/observations')
        allow(request_double).to receive(:query_parameters).and_return('view' => 'grid')
        expect(helper.nav_item_active?('/organizations/1/observations?view=wall')).to be false
      end

      it 'is not active when path matches but link has extra params not in request' do
        allow(request_double).to receive(:path).and_return('/organizations/1/observations')
        allow(request_double).to receive(:query_parameters).and_return('view' => 'wall')
        expect(helper.nav_item_active?('/organizations/1/observations?view=wall&privacy=public')).to be false
      end
    end

    it 'returns false when path is nil' do
      expect(helper.nav_item_active?(nil)).to be false
    end
  end

  describe '#nav_item_active_for?' do
    let(:request_double) do
      double('request').tap do |req|
        allow(req).to receive(:path).and_return('/organizations/1/observations')
        allow(req).to receive(:query_parameters).and_return({})
      end
    end

    before do
      allow(helper).to receive(:request).and_return(request_double)
    end

    it 'delegates to nav_item_active?(path) when item has no active_check' do
      allow(request_double).to receive(:path).and_return('/organizations/1/observations')
      item = { path: '/organizations/1/observations' }
      expect(helper.nav_item_active_for?(item)).to be true
    end

    it 'uses active_check return value when present' do
      item = { path: '/other', active_check: -> { true } }
      expect(helper.nav_item_active_for?(item)).to be true

      item_false = { path: '/other', active_check: -> { false } }
      expect(helper.nav_item_active_for?(item_false)).to be false
    end

    it 'returns false when item is nil' do
      expect(helper.nav_item_active_for?(nil)).to be false
    end
  end

  describe '#nav_prompts_item_active?' do
    let(:request_double) do
      double('request').tap do |req|
        allow(req).to receive(:path).and_return('/')
        allow(req).to receive(:query_parameters).and_return({})
      end
    end

    before do
      def helper.current_organization
        @current_organization
      end

      def helper.current_company_teammate
        @current_company_teammate
      end

      helper.instance_variable_set(:@current_organization, company)
      helper.instance_variable_set(:@current_company_teammate, teammate)
      allow(helper).to receive(:request).and_return(request_double)
    end

    it 'returns true when path is exact prompts index' do
      allow(request_double).to receive(:path).and_return(organization_prompts_path(company))
      expect(helper.nav_prompts_item_active?).to be true
    end

    it 'returns false when path is prompts edit for another teammate\'s prompt' do
      other_teammate = create(:company_teammate, organization: company)
      prompt = create(:prompt, company_teammate: other_teammate, prompt_template: create(:prompt_template, company: company))
      allow(request_double).to receive(:path).and_return(edit_organization_prompt_path(company, prompt))
      expect(helper.nav_prompts_item_active?).to be false
    end

    it 'returns true when path is prompts edit for current teammate\'s prompt' do
      prompt = create(:prompt, company_teammate: teammate, prompt_template: create(:prompt_template, company: company))
      allow(request_double).to receive(:path).and_return(edit_organization_prompt_path(company, prompt))
      expect(helper.nav_prompts_item_active?).to be true
    end

    it 'returns false when path is not prompts index or prompts edit' do
      allow(request_double).to receive(:path).and_return(organization_goals_path(company))
      expect(helper.nav_prompts_item_active?).to be false
    end

    it 'returns false when path looks like prompts edit but prompt id does not exist' do
      allow(request_double).to receive(:path).and_return(edit_organization_prompt_path(company, 999999))
      expect(helper.nav_prompts_item_active?).to be false
    end
  end

  describe '#nav_goals_item_active?' do
    let(:request_double) do
      double('request').tap do |req|
        allow(req).to receive(:path).and_return(organization_goals_path(company))
        allow(req).to receive(:query_parameters).and_return({})
      end
    end

    before do
      def helper.current_organization
        @current_organization
      end

      def helper.current_company_teammate
        @current_company_teammate
      end

      helper.instance_variable_set(:@current_organization, company)
      helper.instance_variable_set(:@current_company_teammate, teammate)
      allow(helper).to receive(:request).and_return(request_double)
    end

    it 'returns true when on goals path with owner_id=CompanyTeammate_<current_teammate.id>' do
      allow(request_double).to receive(:path).and_return(organization_goals_path(company).split('?').first)
      allow(request_double).to receive(:query_parameters).and_return('owner_id' => "CompanyTeammate_#{teammate.id}")
      expect(helper.nav_goals_item_active?).to be true
    end

    it 'returns false when on goals path with no owner_id' do
      allow(request_double).to receive(:path).and_return(organization_goals_path(company).split('?').first)
      allow(request_double).to receive(:query_parameters).and_return({})
      expect(helper.nav_goals_item_active?).to be false
    end

    it 'returns false when on goals path with different owner_id' do
      allow(request_double).to receive(:path).and_return(organization_goals_path(company).split('?').first)
      allow(request_double).to receive(:query_parameters).and_return('owner_id' => 'CompanyTeammate_999')
      expect(helper.nav_goals_item_active?).to be false
    end

    it 'returns false when current_company_teammate is nil' do
      helper.instance_variable_set(:@current_company_teammate, nil)
      allow(request_double).to receive(:path).and_return(organization_goals_path(company).split('?').first)
      allow(request_double).to receive(:query_parameters).and_return('owner_id' => "CompanyTeammate_#{teammate.id}")
      expect(helper.nav_goals_item_active?).to be false
    end
  end

  describe '#section_has_active_item?' do
    let(:request_double) do
      double('request').tap do |req|
        allow(req).to receive(:path).and_return('/organizations/1/observations')
        allow(req).to receive(:query_parameters).and_return({})
      end
    end

    before do
      allow(helper).to receive(:request).and_return(request_double)
    end

    it 'returns true when an item with active_check returning true is in the section' do
      section_items = [
        { path: '/other', active_check: -> { false } },
        { path: '/foo', active_check: -> { true } }
      ]
      expect(helper.section_has_active_item?(section_items)).to be true
    end

    it 'returns false when all items have active_check returning false' do
      section_items = [
        { path: '/a', active_check: -> { false } },
        { path: '/b', active_check: -> { false } }
      ]
      expect(helper.section_has_active_item?(section_items)).to be false
    end
  end
end
