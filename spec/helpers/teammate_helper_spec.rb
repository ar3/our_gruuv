require 'rails_helper'

RSpec.describe TeammateHelper, type: :helper do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let!(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: organization, ended_at: nil) }
  let!(:position_major_level) { create(:position_major_level) }
  let!(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let!(:assignment) { create(:assignment, company: organization) }
  let!(:aspiration) { create(:aspiration, organization: organization) }
  let!(:ability) { create(:ability, organization: organization) }

  before do
    # Set up instance variables that helpers expect
    @organization = organization
  end

  describe '#overall_employee_status' do
    context 'when ready for finalization' do
      before do
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago)
      end
      it 'returns "ready_for_finalization"' do
        expect(helper.overall_employee_status(person, organization)).to eq('ready_for_finalization')
      end
    end

    context 'when needs manager completion' do
      before do
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: 1.day.ago, manager_completed_at: nil)
      end
      it 'returns "needs_manager_completion"' do
        expect(helper.overall_employee_status(person, organization)).to eq('needs_manager_completion')
      end
    end

    context 'when needs employee completion' do
      before do
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: nil, manager_completed_at: 1.day.ago)
      end
      it 'returns "needs_employee_completion"' do
        expect(helper.overall_employee_status(person, organization)).to eq('needs_employee_completion')
      end
    end

    context 'when all complete' do
      before do
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: nil, manager_completed_at: nil)
      end
      it 'returns "all_complete"' do
        expect(helper.overall_employee_status(person, organization)).to eq('all_complete')
      end
    end

    context 'when no check-ins' do
      it 'returns "no_check_ins"' do
        expect(helper.overall_employee_status(person, organization)).to eq('no_check_ins')
      end
    end

    context 'when person has no teammate in organization' do
      let(:other_organization) { create(:organization) }
      it 'returns "unknown"' do
        expect(helper.overall_employee_status(person, other_organization)).to eq('unknown')
      end
    end

    context 'when person is nil' do
      it 'returns "unknown"' do
        expect(helper.overall_employee_status(nil, organization)).to eq('unknown')
      end
    end

    context 'when organization is nil' do
      it 'returns "unknown"' do
        expect(helper.overall_employee_status(person, nil)).to eq('unknown')
      end
    end

    context 'with multiple check-ins in different states' do
      before do
        # Ready for finalization (highest priority)
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago)
        # Needs manager completion (lower priority)
        create(:assignment_check_in, teammate: teammate, assignment: assignment, employee_completed_at: 1.day.ago, manager_completed_at: nil)
      end
      it 'returns highest priority status' do
        expect(helper.overall_employee_status(person, organization)).to eq('ready_for_finalization')
      end
    end
  end

  describe '#overall_status_badge' do
    it 'returns correct badge for "ready_for_finalization"' do
      result = helper.overall_status_badge('ready_for_finalization')
      expect(result).to include('badge bg-warning')
      expect(result).to include('Ready to Finalize')
    end

    it 'returns correct badge for "needs_manager_completion"' do
      result = helper.overall_status_badge('needs_manager_completion')
      expect(result).to include('badge bg-danger')
      expect(result).to include('Needs Manager Input')
    end

    it 'returns correct badge for "needs_employee_completion"' do
      result = helper.overall_status_badge('needs_employee_completion')
      expect(result).to include('badge bg-info')
      expect(result).to include('Needs Employee Input')
    end

    it 'returns correct badge for "all_complete"' do
      result = helper.overall_status_badge('all_complete')
      expect(result).to include('badge bg-success')
      expect(result).to include('All Complete')
    end

    it 'returns correct badge for "no_check_ins"' do
      result = helper.overall_status_badge('no_check_ins')
      expect(result).to include('badge bg-secondary')
      expect(result).to include('No Check-ins')
    end

    it 'returns correct badge for "unknown"' do
      result = helper.overall_status_badge('unknown')
      expect(result).to include('badge bg-secondary')
      expect(result).to include('Unknown')
    end

    it 'returns correct badge for invalid status' do
      result = helper.overall_status_badge('invalid_status')
      expect(result).to include('badge bg-secondary')
      expect(result).to include('Unknown')
    end

    it 'returns correct badge for nil status' do
      result = helper.overall_status_badge(nil)
      expect(result).to include('badge bg-secondary')
      expect(result).to include('Unknown')
    end
  end

  describe '#check_ins_for_employee' do
    it 'returns categorized check-ins' do
      position_ci = create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago)
      assignment_ci = create(:assignment_check_in, teammate: teammate, assignment: assignment, employee_completed_at: 1.day.ago, manager_completed_at: nil)
      aspiration_ci = create(:aspiration_check_in, teammate: teammate, aspiration: aspiration, employee_completed_at: nil, manager_completed_at: 1.day.ago)
      milestone = create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1)

      result = helper.check_ins_for_employee(person, organization)

      expect(result[:position]).to include(position_ci)
      expect(result[:assignments]).to include(assignment_ci)
      expect(result[:aspirations]).to include(aspiration_ci)
      expect(result[:milestones]).to include(milestone)
      expect(result[:ready_for_finalization]).to include(position_ci)
      expect(result[:needs_manager_completion]).to include(assignment_ci)
      expect(result[:needs_employee_completion]).to include(aspiration_ci)
    end

    it 'returns empty arrays when person has no teammate in organization' do
      other_organization = create(:organization)
      result = helper.check_ins_for_employee(person, other_organization)

      expect(result[:position]).to be_empty
      expect(result[:assignments]).to be_empty
      expect(result[:aspirations]).to be_empty
      expect(result[:milestones]).to be_empty
      expect(result[:ready_for_finalization]).to be_empty
      expect(result[:needs_manager_completion]).to be_empty
      expect(result[:needs_employee_completion]).to be_empty
      expect(result[:all_complete]).to be_empty
    end

    it 'handles nil person gracefully' do
      result = helper.check_ins_for_employee(nil, organization)

      expect(result[:position]).to be_empty
      expect(result[:assignments]).to be_empty
      expect(result[:aspirations]).to be_empty
      expect(result[:milestones]).to be_empty
    end

    it 'handles nil organization gracefully' do
      result = helper.check_ins_for_employee(person, nil)

      expect(result[:position]).to be_empty
      expect(result[:assignments]).to be_empty
      expect(result[:aspirations]).to be_empty
      expect(result[:milestones]).to be_empty
    end

    it 'only includes open check-ins' do
      # Create closed check-in (one that has been officially completed)
      closed_check_in = create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, official_check_in_completed_at: 1.day.ago)
      
      result = helper.check_ins_for_employee(person, organization)

      expect(result[:position]).not_to include(closed_check_in)
    end

    it 'only includes active employment tenures' do
      # Get the existing employment_tenure and end it first
      employment_tenure.update!(ended_at: 2.days.ago)
      
      # Create a new tenure with different company to avoid overlap
      other_company = create(:organization)
      ended_tenure = create(:employment_tenure, teammate: teammate, company: other_company, started_at: 10.days.ago, ended_at: 1.day.ago)
      ended_check_in = create(:position_check_in, teammate: teammate, employment_tenure: ended_tenure, employee_completed_at: 1.day.ago, manager_completed_at: nil)
      
      result = helper.check_ins_for_employee(person, organization)

      expect(result[:position]).not_to include(ended_check_in)
    end

    it 'only includes open assignment check-ins' do
      # Create closed check-in (one that has been officially completed)
      ended_check_in = create(:assignment_check_in, teammate: teammate, assignment: assignment, employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, official_check_in_completed_at: 1.day.ago)
      
      result = helper.check_ins_for_employee(person, organization)

      expect(result[:assignments]).not_to include(ended_check_in)
    end
  end

  describe '#ready_for_finalization_count' do
    it 'returns the correct count' do
      create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago)
      create(:assignment_check_in, teammate: teammate, assignment: assignment, employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago)
      
      expect(helper.ready_for_finalization_count(person, organization)).to eq(2)
    end

    it 'returns 0 when no check-ins are ready' do
      create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: 1.day.ago, manager_completed_at: nil)
      
      expect(helper.ready_for_finalization_count(person, organization)).to eq(0)
    end

    it 'handles nil person gracefully' do
      expect(helper.ready_for_finalization_count(nil, organization)).to eq(0)
    end

    it 'handles nil organization gracefully' do
      expect(helper.ready_for_finalization_count(person, nil)).to eq(0)
    end
  end

  describe '#pending_acknowledgements_count' do
    it 'returns the correct count' do
      create(:maap_snapshot, employee: person, company: organization, effective_date: Date.current, employee_acknowledged_at: nil)
      create(:maap_snapshot, employee: person, company: organization, effective_date: Date.current, employee_acknowledged_at: nil)
      
      expect(helper.pending_acknowledgements_count(person, organization)).to eq(2)
    end

    it 'returns 0 when no pending acknowledgements' do
      create(:maap_snapshot, employee: person, company: organization, effective_date: Date.current, employee_acknowledged_at: 1.day.ago)
      
      expect(helper.pending_acknowledgements_count(person, organization)).to eq(0)
    end

    it 'excludes snapshots without effective_date' do
      create(:maap_snapshot, employee: person, company: organization, effective_date: nil, employee_acknowledged_at: nil)
      
      expect(helper.pending_acknowledgements_count(person, organization)).to eq(0)
    end

    it 'handles nil person gracefully' do
      expect(helper.pending_acknowledgements_count(nil, organization)).to eq(0)
    end

    it 'handles nil organization gracefully' do
      expect(helper.pending_acknowledgements_count(person, nil)).to eq(0)
    end
  end

  describe '#check_in_status_badge' do
    let(:check_in) { create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure) }

    it 'returns "Ready" for both_complete' do
      allow(check_in).to receive(:completion_state).and_return(:both_complete)
      result = helper.check_in_status_badge(check_in)
      expect(result).to include('badge bg-warning')
      expect(result).to include('Ready')
    end

    it 'returns "Employee" for manager_complete_employee_open' do
      allow(check_in).to receive(:completion_state).and_return(:manager_complete_employee_open)
      result = helper.check_in_status_badge(check_in)
      expect(result).to include('badge bg-info')
      expect(result).to include('Employee')
    end

    it 'returns "Manager" for manager_open_employee_complete' do
      allow(check_in).to receive(:completion_state).and_return(:manager_open_employee_complete)
      result = helper.check_in_status_badge(check_in)
      expect(result).to include('badge bg-danger')
      expect(result).to include('Manager')
    end

    it 'returns "Draft" for both_open' do
      allow(check_in).to receive(:completion_state).and_return(:both_open)
      result = helper.check_in_status_badge(check_in)
      expect(result).to include('badge bg-secondary')
      expect(result).to include('Draft')
    end

    it 'returns "Unknown" for unknown state' do
      allow(check_in).to receive(:completion_state).and_return(:unknown_state)
      result = helper.check_in_status_badge(check_in)
      expect(result).to include('badge bg-secondary')
      expect(result).to include('Unknown')
    end

    it 'handles nil check_in gracefully' do
      result = helper.check_in_status_badge(nil)
      expect(result).to include('badge bg-secondary')
      expect(result).to include('Unknown')
    end
  end

  describe '#check_in_type_name' do
    it 'returns "Position" for PositionCheckIn' do
      check_in = build(:position_check_in)
      expect(helper.check_in_type_name(check_in)).to eq('Position')
    end

    it 'returns assignment title for AssignmentCheckIn' do
      assignment = build(:assignment, title: 'Project Alpha')
      check_in = build(:assignment_check_in, assignment: assignment)
      expect(helper.check_in_type_name(check_in)).to eq('Project Alpha')
    end

    it 'returns aspiration name for AspirationCheckIn' do
      aspiration = build(:aspiration, name: 'Grow Leadership')
      check_in = build(:aspiration_check_in, aspiration: aspiration)
      expect(helper.check_in_type_name(check_in)).to eq('Grow Leadership')
    end

    it 'returns humanized class name for unknown check-in types' do
      check_in = double(class: double(name: 'UnknownCheckIn'))
      expect(helper.check_in_type_name(check_in)).to eq('Unknown check in')
    end

    it 'handles nil assignment gracefully' do
      check_in = build(:assignment_check_in, assignment: nil)
      expect(helper.check_in_type_name(check_in)).to eq('Assignment')
    end

    it 'handles nil aspiration gracefully' do
      check_in = build(:aspiration_check_in, aspiration: nil)
      expect(helper.check_in_type_name(check_in)).to eq('Aspiration')
    end

    it 'handles nil check_in gracefully' do
      expect(helper.check_in_type_name(nil)).to eq('Unknown')
    end
  end

  describe '#filter_display_name' do
    it 'returns correct display name for manager_filter' do
      expect(helper.filter_display_name('manager_filter', 'direct_reports')).to eq('My Direct Reports')
    end

    it 'returns humanized name for other filter values' do
      expect(helper.filter_display_name('manager_filter', 'other_value')).to eq('Other value')
    end

    it 'handles nil filter_value' do
      expect(helper.filter_display_name('manager_filter', nil)).to eq('')
    end

    it 'handles empty filter_value' do
      expect(helper.filter_display_name('manager_filter', '')).to eq('')
    end
  end

  describe '#clear_filter_url' do
    before do
      allow(helper).to receive(:params).and_return({ controller: 'organizations/employees', action: 'index', manager_filter: 'direct_reports', status: 'active' })
      allow(helper).to receive(:organization_employees_path).with(organization, { status: 'active' }).and_return('/test/path')
    end

    it 'removes manager_filter from params' do
      # Stub the instance variable directly
      helper.instance_variable_set(:@organization, organization)
      result = helper.clear_filter_url('manager_filter', 'direct_reports')
      expect(result).to eq('/test/path')
    end

    it 'handles nil filter_value' do
      # Stub the instance variable directly
      helper.instance_variable_set(:@organization, organization)
      result = helper.clear_filter_url('manager_filter', nil)
      expect(result).to eq('')
    end
  end

  describe '#categorize_check_ins_by_freshness' do
    let(:check_ins) do
      [
        # Fresh check-in (finalized 30 days ago)
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, official_check_in_completed_at: 30.days.ago),
        # Stale but active check-in (finalized 100 days ago, manager completed)
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, official_check_in_completed_at: 100.days.ago, manager_completed_at: 1.day.ago),
        # Stale and inactive check-in (finalized 100 days ago, neither completed)
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, official_check_in_completed_at: 100.days.ago),
        # Never finalized - should be stale_inactive
        create(:assignment_check_in, teammate: teammate, assignment: assignment, official_check_in_completed_at: nil)
      ]
    end

    it 'categorizes check-ins correctly' do
      result = helper.categorize_check_ins_by_freshness(check_ins)
      expect(result[:fresh].count).to eq(1)
      expect(result[:stale_active].count).to eq(1)
      expect(result[:stale_inactive].count).to eq(2)
    end

    it 'handles empty array' do
      result = helper.categorize_check_ins_by_freshness([])
      expect(result[:fresh]).to be_empty
      expect(result[:stale_active]).to be_empty
      expect(result[:stale_inactive]).to be_empty
    end
  end

  describe '#check_in_freshness_summary' do
    let(:check_ins) do
      [
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, official_check_in_completed_at: 30.days.ago),
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, official_check_in_completed_at: 30.days.ago),
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, official_check_in_completed_at: 100.days.ago, manager_completed_at: 1.day.ago)
      ]
    end

    it 'returns correct summary with percentages' do
      result = helper.check_in_freshness_summary(check_ins)
      expect(result[:fresh_count]).to eq(2)
      expect(result[:fresh_percentage]).to eq(67)
      expect(result[:stale_active_count]).to eq(1)
      expect(result[:stale_active_percentage]).to eq(33)
      expect(result[:stale_inactive_count]).to eq(0)
      expect(result[:stale_inactive_percentage]).to eq(0)
    end

    it 'returns nil for empty array' do
      result = helper.check_in_freshness_summary([])
      expect(result).to be_nil
    end
  end

  describe '#render_freshness_progress_bar' do
    let(:summary) do
      {
        fresh_count: 2,
        fresh_percentage: 40,
        stale_active_count: 1,
        stale_active_percentage: 20,
        stale_inactive_count: 2,
        stale_inactive_percentage: 40
      }
    end

    it 'renders progress bar with correct segments' do
      result = helper.render_freshness_progress_bar(summary)
      expect(result).to include('progress')
      expect(result).to include('bg-success')
      expect(result).to include('bg-info')
      expect(result).to include('bg-warning')
    end

    it 'returns message for nil summary' do
      result = helper.render_freshness_progress_bar(nil)
      expect(result).to include('No check-ins')
    end
  end

  describe '#finalization_summary_by_type' do
    let(:check_ins) do
      {
        position: [
          create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, 
                 employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, official_check_in_completed_at: nil)
        ],
        assignments: [
          create(:assignment_check_in, teammate: teammate, assignment: assignment,
                 employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, official_check_in_completed_at: nil)
        ],
        aspirations: [],
        milestones: []
      }
    end

    it 'returns correct counts by type' do
      result = helper.finalization_summary_by_type(check_ins)
      expect(result[:position]).to eq(1)
      expect(result[:assignments]).to eq(1)
      expect(result[:aspirations]).to eq(0)
      expect(result[:total]).to eq(2)
    end

    it 'handles empty check-ins' do
      result = helper.finalization_summary_by_type({ position: [], assignments: [], aspirations: [], milestones: [] })
      expect(result[:total]).to eq(0)
    end
  end

  describe '#acknowledgement_summary_by_type' do
    before do
      create(:maap_snapshot, employee: person, company: organization, change_type: 'position_tenure', 
             effective_date: Date.current, employee_acknowledged_at: nil)
      create(:maap_snapshot, employee: person, company: organization, change_type: 'assignment_management', 
             effective_date: Date.current, employee_acknowledged_at: nil)
      create(:maap_snapshot, employee: person, company: organization, change_type: 'position_tenure', 
             effective_date: Date.current, employee_acknowledged_at: 1.day.ago) # Already acknowledged
    end

    it 'returns correct counts by change type' do
      result = helper.acknowledgement_summary_by_type(person, organization)
      expect(result[:position]).to eq(1)
      expect(result[:assignments]).to eq(1)
      expect(result[:aspirations]).to eq(0)
      expect(result[:milestones]).to eq(0)
      expect(result[:bulk]).to eq(0)
      expect(result[:total]).to eq(2)
    end

    it 'excludes already acknowledged snapshots' do
      result = helper.acknowledgement_summary_by_type(person, organization)
      expect(result[:total]).to eq(2)
      expect(result[:position]).to eq(1) # Only one unacknowledged position snapshot
    end

    it 'handles nil person gracefully' do
      result = helper.acknowledgement_summary_by_type(nil, organization)
      expect(result[:total]).to eq(0)
    end

    it 'handles nil organization gracefully' do
      result = helper.acknowledgement_summary_by_type(person, nil)
      expect(result[:total]).to eq(0)
    end
  end

  describe '#teammate_organization_display' do
    let(:company) { create(:organization, :company, name: 'Acme Corp') }
    let(:department1) { create(:organization, :department, name: 'Engineering', parent: company) }
    let(:department2) { create(:organization, :department, name: 'Sales', parent: company) }
    let(:team1) { create(:organization, :team, name: 'Frontend Team', parent: department1) }
    let(:team2) { create(:organization, :team, name: 'Backend Team', parent: department1) }
    
    before do
      @organization = company
    end

    context 'when person has teammates in multiple departments and teams' do
      let!(:teammate_dept1) { create(:teammate, person: person, organization: department1) }
      let!(:teammate_dept2) { create(:teammate, person: person, organization: department2) }
      let!(:teammate_team1) { create(:teammate, person: person, organization: team1) }
      let!(:teammate_team2) { create(:teammate, person: person, organization: team2) }

      it 'displays all departments and teams as comma-separated list' do
        result = helper.teammate_organization_display(teammate_dept1)
        expect(result).to include('Backend Team')
        expect(result).to include('Engineering')
        expect(result).to include('Frontend Team')
        expect(result).to include('Sales')
        expect(result).not_to include('Acme Corp')
      end

      it 'sorts organizations alphabetically' do
        result = helper.teammate_organization_display(teammate_dept1)
        # Check that names appear in alphabetical order
        expect(result).to match(/Backend Team.*Engineering.*Frontend Team.*Sales/)
      end

      it 'excludes the company from the list' do
        result = helper.teammate_organization_display(teammate_dept1)
        expect(result).not_to include('Acme Corp')
      end
    end

    context 'when person only has teammate in company (no departments/teams)' do
      let!(:teammate_company) { create(:teammate, person: person, organization: company) }

      it 'displays em dash when no departments/teams' do
        result = helper.teammate_organization_display(teammate_company)
        expect(result).to include('—')
      end
    end

    context 'when person has teammates in departments only' do
      let!(:teammate_dept1) { create(:teammate, person: person, organization: department1) }
      let!(:teammate_dept2) { create(:teammate, person: person, organization: department2) }

      it 'displays only departments' do
        result = helper.teammate_organization_display(teammate_dept1)
        expect(result).to include('Engineering')
        expect(result).to include('Sales')
        expect(result).not_to include('Acme Corp')
      end
    end

    context 'when person has teammates in teams only' do
      let!(:teammate_team1) { create(:teammate, person: person, organization: team1) }
      let!(:teammate_team2) { create(:teammate, person: person, organization: team2) }

      it 'displays only teams' do
        result = helper.teammate_organization_display(teammate_team1)
        expect(result).to include('Backend Team')
        expect(result).to include('Frontend Team')
        expect(result).not_to include('Acme Corp')
        expect(result).not_to include('Engineering')
      end
    end

    context 'when viewing from a department context' do
      before do
        @organization = department1
      end

      let!(:teammate_dept1) { create(:teammate, person: person, organization: department1) }
      let!(:teammate_team1) { create(:teammate, person: person, organization: team1) }

      it 'still finds all departments/teams within the company hierarchy' do
        result = helper.teammate_organization_display(teammate_dept1)
        expect(result).to include('Engineering')
        expect(result).to include('Frontend Team')
        expect(result).not_to include('Acme Corp')
      end
    end

    context 'when person has teammates in different companies' do
      let(:other_company) { create(:organization, :company, name: 'Other Corp') }
      let(:other_dept) { create(:organization, :department, name: 'Other Dept', parent: other_company) }
      let!(:teammate_dept1) { create(:teammate, person: person, organization: department1) }
      let!(:teammate_other_dept) { create(:teammate, person: person, organization: other_dept) }

      it 'only shows departments/teams from the current company' do
        result = helper.teammate_organization_display(teammate_dept1)
        expect(result).to include('Engineering')
        expect(result).not_to include('Other Dept')
        expect(result).not_to include('Other Corp')
      end
    end

    context 'edge cases' do
      it 'handles nil teammate gracefully' do
        result = helper.teammate_organization_display(nil)
        expect(result).to eq('')
      end

      it 'handles teammate with nil person gracefully' do
        teammate_nil_person = build(:teammate, person: nil)
        result = helper.teammate_organization_display(teammate_nil_person)
        expect(result).to eq('')
      end

      it 'handles nil @organization gracefully' do
        @organization = nil
        teammate = create(:teammate, person: person, organization: department1)
        result = helper.teammate_organization_display(teammate)
        expect(result).to eq('')
      end

      it 'handles multiple teammates in same organization gracefully' do
        # Create teammate in department
        teammate1 = create(:teammate, person: person, organization: department1)
        
        result = helper.teammate_organization_display(teammate1)
        # Should only show department once (even if queried multiple times)
        expect(result.scan('Engineering').count).to eq(1)
        expect(result).to include('Engineering')
      end
    end
  end

  describe '#teammate_profile_image' do
    context 'when teammate has Slack profile image' do
      let!(:slack_identity) { create(:teammate_identity, :slack, teammate: teammate, profile_image_url: 'https://slack.com/avatar.jpg') }

      it 'returns image tag with Slack profile image' do
        result = helper.teammate_profile_image(teammate, size: 48)
        expect(result).to include('img')
        expect(result).to include('https://slack.com/avatar.jpg')
        expect(result).to include('rounded-circle')
        expect(result).to include('width: 48px')
        expect(result).to include('height: 48px')
      end
    end

    context 'when teammate has Google profile image but no Slack' do
      let!(:google_identity) { create(:person_identity, :google, person: person, profile_image_url: 'https://google.com/avatar.jpg') }

      it 'returns image tag with Google profile image' do
        result = helper.teammate_profile_image(teammate, size: 32)
        expect(result).to include('img')
        expect(result).to include('https://google.com/avatar.jpg')
        expect(result).to include('width: 32px')
        expect(result).to include('height: 32px')
      end
    end

    context 'when teammate has no profile images' do
      it 'returns initials in colored circle' do
        person.update!(first_name: 'John', last_name: 'Doe')
        result = helper.teammate_profile_image(teammate, size: 48)
        
        expect(result).to include('bg-primary')
        expect(result).to include('rounded-circle')
        expect(result).to include('J')
        expect(result).to include('width: 48px')
        expect(result).to include('height: 48px')
      end

      it 'falls back to email first letter when no first name' do
        person.update!(first_name: nil, email: 'test@example.com')
        result = helper.teammate_profile_image(teammate, size: 32)
        
        expect(result).to include('T')
      end
    end
  end
end
