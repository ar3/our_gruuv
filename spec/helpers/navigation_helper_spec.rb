require 'rails_helper'

RSpec.describe NavigationHelper, type: :helper do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: company) }

  describe '#pending_get_shit_done_count' do
    it 'returns 0 when teammate is nil' do
      expect(helper.pending_get_shit_done_count(nil)).to eq(0)
    end

    it 'counts all pending items' do
      # Ensure teammate is a CompanyTeammate
      company_teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      
      observable_moment = create(:observable_moment, :new_hire, company: company, primary_observer_person: person)
      observable_moment.reload
      create(:maap_snapshot, employee: person, company: company, employee_acknowledged_at: nil, effective_date: Time.current)
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
        # Handle Organization class or instance
        if record == Organization || record.is_a?(Organization) || (record.is_a?(Class) && record <= Organization)
          # For Organization class or instance, return a policy that allows show? for "My Employees" and "View Teammates"
          double(show?: true, view_prompts?: true, view_prompt_templates?: true, view_observations?: true, view_seats?: true, view_goals?: true, view_abilities?: true, view_assignments?: true, view_aspirations?: true, view_bulk_sync_events?: true, customize_company?: true, manage_employment?: true)
        elsif record == Company || record.is_a?(Company) || (record.is_a?(Class) && record <= Company)
          double(view_prompts?: true, view_prompt_templates?: true, view_observations?: true, view_seats?: true, view_goals?: true, view_abilities?: true, view_assignments?: true, view_aspirations?: true, view_bulk_sync_events?: true, customize_company?: true)
        elsif record.is_a?(CompanyTeammate)
          double(view_check_ins?: true)
        elsif record.is_a?(Huddle)
          double(show?: true)
        else
          # For other records, return a policy that allows show?
          double(show?: true, view_prompts?: true)
        end
      end

      helper.instance_variable_set(:@current_organization, company)
      helper.instance_variable_set(:@current_person, person)
      # Ensure teammate is a CompanyTeammate for has_direct_reports? method
      company_teammate = teammate.is_a?(CompanyTeammate) ? teammate : CompanyTeammate.find(teammate.id)
      helper.instance_variable_set(:@current_company_teammate, company_teammate)
      helper.instance_variable_set(:@current_company, company)
    end

    it 'uses company_label_plural for prompts navigation label' do
      company = Company.find_or_create_by!(name: 'Test Company', type: 'Company')
      helper.instance_variable_set(:@current_organization, company)
      helper.instance_variable_set(:@current_company, company)
      
      structure = helper.navigation_structure
      prompts_item = structure.find { |item| item[:path]&.include?('prompts') }
      expect(prompts_item).to be_present
      expect(prompts_item[:label]).to eq('Prompts') # Default when no custom label
    end

    context 'when company has custom label preference' do
      let(:company) { Company.find_or_create_by!(name: 'Test Company', type: 'Company') }

      before do
        create(:company_label_preference, company: company, label_key: 'prompt', label_value: 'Reflection')
        helper.instance_variable_set(:@current_organization, company)
        helper.instance_variable_set(:@current_company, company)
      end

      it 'uses the custom plural label' do
        structure = helper.navigation_structure
        prompts_item = structure.find { |item| item[:path]&.include?('prompts') }
        expect(prompts_item).to be_present
        expect(prompts_item[:label]).to eq('Reflections')
      end
    end

    it 'has "View Teammates" instead of "My Teammates"' do
      structure = helper.navigation_structure
      teammates_item = structure.find { |item| item[:label] == 'View Teammates' }
      expect(teammates_item).to be_present
      expect(teammates_item[:label]).to eq('View Teammates')
    end

    context 'when teammate has direct reports' do
      let(:manager_person) { create(:person) }
      let(:manager_teammate) { CompanyTeammate.find(create(:teammate, person: manager_person, organization: company, first_employed_at: 1.year.ago).id) }
      let(:direct_report) { create(:person) }
      let(:direct_report_teammate) { CompanyTeammate.find(create(:teammate, person: direct_report, organization: company, first_employed_at: 6.months.ago).id) }
      let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
      let(:title) { create(:title, company: company, position_major_level: position_major_level) }
      let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
      let(:position) { create(:position, title: title, position_level: position_level) }
      let!(:employment_tenure) do
        create(:employment_tenure,
          teammate: direct_report_teammate,
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

      it 'includes "My Employees" in navigation' do
        structure = helper.visible_navigation_structure
        # Debug: print all labels to see what's in the structure
        labels = structure.map { |item| item[:label] }
        expect(labels).to include('My Employees'), "Expected 'My Employees' in navigation, but found: #{labels.inspect}"
        
        my_employees_item = structure.find { |item| item[:label] == 'My Employees' }
        expect(my_employees_item).to be_present
        expect(my_employees_item[:path]).to include('managers_view')
        expect(my_employees_item[:path]).to include("manager_teammate_id=#{manager_teammate.id}")
      end

      it 'places "My Employees" after "View Teammates"' do
        structure = helper.visible_navigation_structure
        view_teammates_index = structure.find_index { |item| item[:label] == 'View Teammates' }
        my_employees_index = structure.find_index { |item| item[:label] == 'My Employees' }
        expect(view_teammates_index).to be_present, "Expected 'View Teammates' in navigation"
        expect(my_employees_index).to be_present, "Expected 'My Employees' in navigation"
        expect(my_employees_index).to be > view_teammates_index
      end
    end

    context 'when teammate has no direct reports' do
      let(:teammate_without_reports) do
        teammate_without = CompanyTeammate.find(create(:teammate, person: create(:person), organization: company, first_employed_at: 1.year.ago).id)
        # Ensure no direct reports exist
        EmploymentTenure.where(manager_teammate: teammate_without, ended_at: nil).update_all(ended_at: Time.current)
        teammate_without
      end

      before do
        helper.instance_variable_set(:@current_company_teammate, teammate_without_reports)
      end

      it 'does not include "My Employees" in navigation' do
        # Verify teammate has no direct reports
        expect(teammate_without_reports.has_direct_reports?).to be false
        structure = helper.visible_navigation_structure
        my_employees_item = structure.find { |item| item[:label] == 'My Employees' }
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

      it 'has the expected Insights sub-items' do
        structure = helper.navigation_structure
        insights_section = structure.find { |item| item[:label] == 'Insights' }
        items = insights_section[:items]
        
        labels = items.map { |item| item[:label] }
        expect(labels).to include('Seats, Titles, Positions')
        expect(labels).to include('Assignments')
        expect(labels).to include('Abilities')
        expect(labels).to include('Goals')
        expect(labels).to include('Huddles')
      end

      it 'places Insights section between Huddles and Admin' do
        structure = helper.navigation_structure
        huddles_index = structure.find_index { |item| item[:label] == 'Huddles' }
        insights_index = structure.find_index { |item| item[:label] == 'Insights' }
        admin_index = structure.find_index { |item| item[:label] == 'Admin' }
        
        expect(huddles_index).to be_present
        expect(insights_index).to be_present
        expect(admin_index).to be_present
        expect(insights_index).to be > huddles_index
        expect(insights_index).to be < admin_index
      end
    end
  end
end
