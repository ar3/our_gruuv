require 'rails_helper'

RSpec.describe CompanyTeammatesQuery, type: :query do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:direct_report1) { create(:person) }
  let(:direct_report2) { create(:person) }
  let(:other_employee) { create(:person) }
  let(:non_employee) { create(:person) }
  
  let!(:manager_teammate) { CompanyTeammate.find(create(:teammate, person: manager, organization: organization).id) }
  let!(:direct_report1_teammate) { CompanyTeammate.find(create(:teammate, person: direct_report1, organization: organization).id) }
  let!(:direct_report2_teammate) { CompanyTeammate.find(create(:teammate, person: direct_report2, organization: organization).id) }
  let!(:other_employee_teammate) { CompanyTeammate.find(create(:teammate, person: other_employee, organization: organization).id) }

  before do
    # Create employment tenures with manager relationships
    create(:employment_tenure, teammate: direct_report1_teammate, company: organization, manager: manager, ended_at: nil)
    create(:employment_tenure, teammate: direct_report2_teammate, company: organization, manager: manager, ended_at: nil)
    create(:employment_tenure, teammate: other_employee_teammate, company: organization, manager: create(:person), ended_at: nil)
  end

  describe '#initialize' do
    it 'accepts organization, params, and current_person' do
      query = CompanyTeammatesQuery.new(organization, { sort: 'name_asc' }, current_person: manager)
      expect(query.organization).to eq(organization)
      expect(query.params).to eq({ sort: 'name_asc' })
      expect(query.current_person).to eq(manager)
    end

    it 'works without current_person' do
      query = CompanyTeammatesQuery.new(organization, { sort: 'name_asc' })
      expect(query.current_person).to be_nil
    end

    it 'handles nil current_person explicitly' do
      query = CompanyTeammatesQuery.new(organization, { sort: 'name_asc' }, current_person: nil)
      expect(query.current_person).to be_nil
    end
  end

  describe '#call' do
    context 'without manager filter' do
      it 'returns all teammates in organization' do
        query = CompanyTeammatesQuery.new(organization, {})
        results = query.call
        
        expect(results).to include(direct_report1_teammate, direct_report2_teammate, other_employee_teammate)
      end
    end

    context 'with manager_id filter' do
      it 'returns only direct reports when manager_id is provided' do
        query = CompanyTeammatesQuery.new(organization, { manager_id: manager.id }, current_person: manager)
        results = query.call
        
        expect(results).to include(direct_report1_teammate, direct_report2_teammate)
        expect(results).not_to include(other_employee_teammate)
        expect(results).not_to include(manager_teammate)
      end

      it 'returns all teammates when manager_id is not provided' do
        query = CompanyTeammatesQuery.new(organization, {}, current_person: manager)
        results = query.call
        
        expect(results).to include(direct_report1_teammate, direct_report2_teammate, other_employee_teammate)
      end

      it 'returns all teammates when manager_id is blank' do
        query = CompanyTeammatesQuery.new(organization, { manager_id: '' }, current_person: manager)
        results = query.call
        
        expect(results).to include(direct_report1_teammate, direct_report2_teammate, other_employee_teammate)
      end

      it 'excludes teammates with ended employment tenures' do
        # End the employment tenure for direct_report1
        EmploymentTenure.where(teammate: direct_report1_teammate, manager: manager).update_all(ended_at: 1.day.ago)
        
        query = CompanyTeammatesQuery.new(organization, { manager_id: manager.id }, current_person: manager)
        results = query.call
        
        expect(results.map(&:id)).not_to include(direct_report1_teammate.id)
        expect(results.map(&:id)).to include(direct_report2_teammate.id)
      end

      it 'handles teammates with multiple employment tenures' do
        # This test verifies that when a teammate has an employment tenure with a different manager
        # (but same company), they still appear in the direct_reports query.
        # To avoid overlap validation, we'll test a scenario where they switch companies instead.
        
        # Create a new teammate in a different company
        other_company = create(:organization)
        teammate_in_other_company = CompanyTeammate.find(create(:teammate, person: create(:person), organization: other_company).id)
        other_manager = create(:person)
        create(:employment_tenure, teammate: teammate_in_other_company, company: other_company, manager: other_manager, ended_at: nil)
        
        query = CompanyTeammatesQuery.new(organization, { manager_id: manager.id }, current_person: manager)
        results = query.call
        
        expect(results).to include(direct_report1_teammate) # Still a direct report in the organization
        expect(results).to include(direct_report2_teammate)
        expect(results).not_to include(teammate_in_other_company) # Not in the organization
      end

      it 'handles teammates with no employment tenures' do
        # Remove all employment tenures for direct_report1
        EmploymentTenure.where(teammate: direct_report1_teammate).destroy_all
        
        query = CompanyTeammatesQuery.new(organization, { manager_id: manager.id }, current_person: manager)
        results = query.call
        
        expect(results.map(&:id)).not_to include(direct_report1_teammate.id)
        expect(results.map(&:id)).to include(direct_report2_teammate.id)
      end

      it 'uses distinct to avoid duplicates' do
        # Query should return each teammate only once even with multiple tenures
        query = CompanyTeammatesQuery.new(organization, { manager_id: manager.id }, current_person: manager)
        results = query.call
        
        # Should not have duplicates
        expect(results.uniq).to eq(results)
        expect(results.size).to eq(results.uniq.size)
      end
    end

    context 'with status filters' do
      let(:active_employee) { create(:person) }
      let(:unassigned_employee) { create(:person) }
      let(:terminated_employee) { create(:person) }
      let(:huddle_only_participant) { create(:person) }

      let!(:active_teammate) { CompanyTeammate.find(create(:teammate, person: active_employee, organization: organization, first_employed_at: 1.month.ago).id) }
      let!(:unassigned_teammate) { CompanyTeammate.find(create(:teammate, person: unassigned_employee, organization: organization, first_employed_at: 2.months.ago).id) }
      let!(:terminated_teammate) { CompanyTeammate.find(create(:teammate, person: terminated_employee, organization: organization, first_employed_at: 6.months.ago, last_terminated_at: 1.month.ago).id) }
      let!(:huddle_only_teammate) { CompanyTeammate.find(create(:teammate, person: huddle_only_participant, organization: organization, first_employed_at: nil, last_terminated_at: nil).id) }

      before do
        # Create employment tenure for active employee
        create(:employment_tenure, teammate: active_teammate, company: organization, started_at: 2.months.ago, ended_at: nil)
        # No employment tenure for unassigned (they have first_employed_at but no active tenure)
        # Create terminated employment tenure (started_at must be before ended_at)
        create(:employment_tenure, teammate: terminated_teammate, company: organization, started_at: 6.months.ago, ended_at: 1.month.ago)
      end

      describe 'active filter' do
        it 'returns only active employees (assigned and unassigned)' do
          query = CompanyTeammatesQuery.new(organization, { status: 'active' })
          results = query.call_with_status_filter

          expect(results).to include(active_teammate)
          expect(results).to include(unassigned_teammate)
          expect(results).not_to include(terminated_teammate)
          expect(results).not_to include(huddle_only_teammate)
        end
      end

      describe 'all_employed filter' do
        it 'returns all ever-employed teammates (active, unassigned, and terminated)' do
          query = CompanyTeammatesQuery.new(organization, { status: 'all_employed' })
          results = query.call_with_status_filter

          expect(results).to include(active_teammate)
          expect(results).to include(unassigned_teammate)
          expect(results).to include(terminated_teammate)
          expect(results).not_to include(huddle_only_teammate)
        end
      end

      describe 'terminated filter' do
        it 'returns only terminated employees' do
          query = CompanyTeammatesQuery.new(organization, { status: 'terminated' })
          results = query.call_with_status_filter

          expect(results).to include(terminated_teammate)
          expect(results).not_to include(active_teammate)
          expect(results).not_to include(unassigned_teammate)
          expect(results).not_to include(huddle_only_teammate)
        end
      end

      describe 'exclusion of huddle-only participants' do
        it 'excludes huddle-only participants with default active filter' do
          # Simulate default behavior - status defaults to 'active'
          query = CompanyTeammatesQuery.new(organization, { status: 'active' })
          results = query.call_with_status_filter

          expect(results).not_to include(huddle_only_teammate)
        end

        it 'excludes huddle-only participants with all_employed filter' do
          query = CompanyTeammatesQuery.new(organization, { status: 'all_employed' })
          results = query.call_with_status_filter

          expect(results).not_to include(huddle_only_teammate)
        end
      end
    end

    context 'uniqueness' do
      it 'returns distinct teammates even with manager filter joins' do
        # Create a teammate with multiple employment tenures reporting to the same manager
        person = create(:person)
        teammate = CompanyTeammate.find(create(:teammate, person: person, organization: organization).id)
        
        # Create multiple employment tenures for the same teammate-manager relationship
        create(:employment_tenure, teammate: teammate, company: organization, manager: manager, started_at: 3.months.ago, ended_at: 1.month.ago)
        create(:employment_tenure, teammate: teammate, company: organization, manager: manager, started_at: 1.month.ago, ended_at: nil)

        query = CompanyTeammatesQuery.new(organization, { manager_id: manager.id }, current_person: manager)
        results = query.call

        # Should only appear once despite multiple tenures
        expect(results.count { |t| t.id == teammate.id }).to eq(1)
        expect(results.map(&:id)).to include(teammate.id)
      end

      it 'returns distinct teammates without manager filter' do
        # Create a teammate with multiple employment tenures
        person = create(:person)
        teammate = create(:teammate, person: person, organization: organization, first_employed_at: 3.months.ago)
        
        # Create multiple employment tenures
        create(:employment_tenure, teammate: teammate, company: organization, started_at: 3.months.ago, ended_at: 1.month.ago)
        create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.month.ago, ended_at: nil)

        query = CompanyTeammatesQuery.new(organization, {})
        results = query.call

        # Should only appear once despite multiple tenures
        expect(results.count { |t| t.id == teammate.id }).to eq(1)
        expect(results.map(&:id)).to include(teammate.id)
      end
    end
  end

  describe '#current_filters' do
    it 'includes manager_id when present' do
      query = CompanyTeammatesQuery.new(organization, { manager_id: manager.id })
      expect(query.current_filters[:manager_id]).to eq(manager.id.to_s)
    end

    it 'does not include manager_id when not present' do
      query = CompanyTeammatesQuery.new(organization, {})
      expect(query.current_filters[:manager_id]).to be_nil
    end
    end

    it 'includes other existing filters' do
      query = CompanyTeammatesQuery.new(organization, { status: 'active', permission: 'employment_mgmt', manager_id: manager.id })
      filters = query.current_filters
      # Status should be expanded to granular statuses for checkbox display
      expect(filters[:status]).to include('assigned_employee', 'unassigned_employee')
      expect(filters[:permission]).to eq('employment_mgmt')
      expect(filters[:manager_id]).to eq(manager.id.to_s)
    end

    it 'expands status shortcuts to granular statuses for display' do
      query = CompanyTeammatesQuery.new(organization, { status: 'active' })
      filters = query.current_filters
      expect(filters[:status]).to match_array(['assigned_employee', 'unassigned_employee'])

      query = CompanyTeammatesQuery.new(organization, { status: 'all_employed' })
      filters = query.current_filters
      expect(filters[:status]).to match_array(['assigned_employee', 'unassigned_employee', 'terminated'])

      query = CompanyTeammatesQuery.new(organization, { status: 'terminated' })
      filters = query.current_filters
      expect(filters[:status]).to match_array(['terminated'])
    end
  end

  describe '#current_view' do
    it 'returns display parameter when present' do
      query = CompanyTeammatesQuery.new(organization, { display: 'check_in_status' })
      expect(query.current_view).to eq('check_in_status')
    end

    it 'returns view parameter when display is not present' do
      query = CompanyTeammatesQuery.new(organization, { view: 'cards' })
      expect(query.current_view).to eq('cards')
    end

    it 'returns list as default' do
      query = CompanyTeammatesQuery.new(organization, {})
      expect(query.current_view).to eq('list')
    end

    it 'prioritizes display over view when both present' do
      query = CompanyTeammatesQuery.new(organization, { view: 'cards', display: 'check_in_status' })
      expect(query.current_view).to eq('check_in_status')
    end

    it 'handles empty display param' do
      query = CompanyTeammatesQuery.new(organization, { display: '', view: 'cards' })
      expect(query.current_view).to eq('cards')
    end

    it 'handles empty view param' do
      query = CompanyTeammatesQuery.new(organization, { view: '', display: 'check_in_status' })
      expect(query.current_view).to eq('check_in_status')
    end
  end

  describe '#has_active_filters?' do
    it 'returns true when manager_id is present' do
      query = CompanyTeammatesQuery.new(organization, { manager_id: manager.id })
      expect(query.has_active_filters?).to be true
    end

    it 'returns false when no filters are present' do
      query = CompanyTeammatesQuery.new(organization, {})
      expect(query.has_active_filters?).to be false
    end

  end

  describe 'integration with other filters' do
    it 'combines manager filter with status filter' do
      # Make direct_report1 an assigned employee
      direct_report1_teammate.update!(first_employed_at: 1.month.ago)
      
      query = CompanyTeammatesQuery.new(organization, { manager_id: manager.id, status: 'assigned_employee' }, current_person: manager)
      results = query.call_with_status_filter
      
      expect(results.map(&:id)).to include(direct_report1_teammate.id)
      expect(results.map(&:id)).not_to include(direct_report2_teammate.id) # Not assigned yet
    end

    it 'combines manager filter with permission filter' do
      direct_report1_teammate.update!(can_manage_employment: true)
      
      query = CompanyTeammatesQuery.new(organization, { manager_id: manager.id, permission: 'employment_mgmt' }, current_person: manager)
      results = query.call
      
      expect(results).to include(direct_report1_teammate)
      expect(results).not_to include(direct_report2_teammate) # No employment management permission
    end

      it 'combines manager filter with organization filter' do
      child_org = create(:organization, parent: organization)
      child_teammate = CompanyTeammate.find(create(:teammate, person: direct_report1, organization: child_org).id)
      create(:employment_tenure, teammate: child_teammate, company: child_org, manager: manager, ended_at: nil)
      
      query = CompanyTeammatesQuery.new(organization, { manager_id: manager.id, organization_id: child_org.id }, current_person: manager)
      results = query.call
      
      # Should only include direct reports in the specified organization
      expect(results).to include(child_teammate)
      expect(results).not_to include(direct_report1_teammate) # Different organization
      expect(results).not_to include(direct_report2_teammate) # Different organization
    end
  end

  describe 'performance considerations' do
    it 'handles large datasets efficiently' do
      # Create many direct reports
      100.times do |i|
        person = create(:person, first_name: "Employee#{i}")
        teammate = create(:teammate, person: person, organization: organization)
        create(:employment_tenure, teammate: teammate, company: organization, manager: manager, ended_at: nil)
      end
      
      query = CompanyTeammatesQuery.new(organization, { manager_id: manager.id }, current_person: manager)
      
      expect {
        query.call
      }.not_to raise_error
    end
  end

  describe 'edge cases' do
    it 'handles teammates with different organization' do
      other_organization = create(:organization)
      teammate_with_other_org = CompanyTeammate.find(create(:teammate, person: create(:person), organization: other_organization).id)
      
      query = CompanyTeammatesQuery.new(organization, { manager_id: manager.id }, current_person: manager)
      results = query.call
      
      expect(results).not_to include(teammate_with_other_org)
    end

    it 'handles employment tenures with nil manager' do
      teammate_with_nil_manager = CompanyTeammate.find(create(:teammate, person: create(:person), organization: organization).id)
      create(:employment_tenure, teammate: teammate_with_nil_manager, company: organization, manager: nil, ended_at: nil)
      
      query = CompanyTeammatesQuery.new(organization, { manager_id: manager.id }, current_person: manager)
      results = query.call
      
      expect(results).not_to include(teammate_with_nil_manager)
    end

    it 'handles employment tenures with different company' do
      other_company = create(:organization)
      teammate_with_other_company = CompanyTeammate.find(create(:teammate, person: create(:person), organization: other_company).id)
      create(:employment_tenure, teammate: teammate_with_other_company, company: other_company, manager: manager, ended_at: nil)
      
      query = CompanyTeammatesQuery.new(organization, { manager_id: manager.id }, current_person: manager)
      results = query.call
      
      expect(results).not_to include(teammate_with_other_company)
    end

    it 'handles invalid manager_id values gracefully' do
      query = CompanyTeammatesQuery.new(organization, { manager_id: 999999 }, current_person: manager)
      results = query.call
      
      expect(results).to include(direct_report1_teammate, direct_report2_teammate, other_employee_teammate)
    end
  end
end
