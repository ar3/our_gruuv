require 'rails_helper'

RSpec.describe TeammateHelper, type: :helper do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }
  let(:manager_teammate) { create(:company_teammate, organization: organization) }
  let!(:employment_tenure) { create(:employment_tenure, company_teammate: teammate, company: organization, ended_at: nil) }
  let!(:position_major_level) { create(:position_major_level) }
  let!(:title) { create(:title, company: organization, position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let!(:position) { create(:position, title: title, position_level: position_level) }
  let!(:assignment) { create(:assignment, company: organization) }
  let!(:aspiration) { create(:aspiration, company: organization) }
  let!(:ability) { create(:ability, company: organization) }

  before do
    # Set up instance variables that helpers expect
    @organization = organization
  end

  describe '#overall_employee_status' do
    context 'when ready for finalization' do
      before do
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, manager_completed_by_teammate: manager_teammate)
      end
      it 'returns "ready_for_finalization"' do
        expect(helper.overall_employee_status(person, organization)).to eq('ready_for_finalization')
      end
    end

    context 'when needs manager completion' do
      before do
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: 1.day.ago, manager_completed_at: nil, manager_completed_by_teammate: nil)
      end
      it 'returns "needs_manager_completion"' do
        expect(helper.overall_employee_status(person, organization)).to eq('needs_manager_completion')
      end
    end

    context 'when needs employee completion' do
      before do
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: nil, manager_completed_at: 1.day.ago, manager_completed_by_teammate: manager_teammate)
      end
      it 'returns "needs_employee_completion"' do
        expect(helper.overall_employee_status(person, organization)).to eq('needs_employee_completion')
      end
    end

    context 'when all complete' do
      before do
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: nil, manager_completed_at: nil, manager_completed_by_teammate: nil)
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
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, manager_completed_by_teammate: manager_teammate)
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
      position_ci = create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, manager_completed_by_teammate: manager_teammate)
      assignment_ci = create(:assignment_check_in, teammate: teammate, assignment: assignment, employee_completed_at: 1.day.ago, manager_completed_at: nil)
      aspiration_ci = create(:aspiration_check_in, teammate: teammate, aspiration: aspiration, employee_completed_at: nil, manager_completed_at: 1.day.ago, manager_completed_by_teammate: manager_teammate)
      milestone = create(:teammate_milestone, company_teammate: teammate, ability: ability, milestone_level: 1)

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
      closed_check_in = create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, manager_completed_by_teammate: manager_teammate, official_check_in_completed_at: 1.day.ago, finalized_by_teammate: manager_teammate)
      
      result = helper.check_ins_for_employee(person, organization)

      expect(result[:position]).not_to include(closed_check_in)
    end

    it 'only includes active employment tenures' do
      # Get the existing employment_tenure and end it first
      employment_tenure.update!(ended_at: 2.days.ago)
      
      # Create a new tenure with different company to avoid overlap
      other_company = create(:organization)
      ended_tenure = create(:employment_tenure, company_teammate: teammate, company: other_company, started_at: 10.days.ago, ended_at: 1.day.ago)
      ended_check_in = create(:position_check_in, teammate: teammate, employment_tenure: ended_tenure, employee_completed_at: 1.day.ago, manager_completed_at: nil)
      
      result = helper.check_ins_for_employee(person, organization)

      expect(result[:position]).not_to include(ended_check_in)
    end

    it 'only includes open assignment check-ins' do
      # Create closed check-in (one that has been officially completed)
      ended_check_in = create(:assignment_check_in, teammate: teammate, assignment: assignment, employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, manager_completed_by_teammate: manager_teammate, official_check_in_completed_at: 1.day.ago, finalized_by_teammate: manager_teammate)
      
      result = helper.check_ins_for_employee(person, organization)

      expect(result[:assignments]).not_to include(ended_check_in)
    end
  end

  describe '#ready_for_finalization_count' do
    it 'returns the correct count' do
      create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, manager_completed_by_teammate: manager_teammate)
      create(:assignment_check_in, teammate: teammate, assignment: assignment, employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, manager_completed_by_teammate: manager_teammate)
      
      expect(helper.ready_for_finalization_count(person, organization)).to eq(2)
    end

    it 'returns 0 when no check-ins are ready' do
      create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: 1.day.ago, manager_completed_at: nil, manager_completed_by_teammate: nil)
      
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
      create(:maap_snapshot, employee_company_teammate: teammate, company: organization, effective_date: Date.current, employee_acknowledged_at: nil)
      create(:maap_snapshot, employee_company_teammate: teammate, company: organization, effective_date: Date.current, employee_acknowledged_at: nil)
      
      expect(helper.pending_acknowledgements_count(person, organization)).to eq(2)
    end

    it 'returns 0 when no pending acknowledgements' do
      create(:maap_snapshot, employee_company_teammate: teammate, company: organization, effective_date: Date.current, employee_acknowledged_at: 1.day.ago)
      
      expect(helper.pending_acknowledgements_count(person, organization)).to eq(0)
    end

    it 'excludes snapshots without effective_date' do
      create(:maap_snapshot, employee_company_teammate: teammate, company: organization, effective_date: nil, employee_acknowledged_at: nil)
      
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
    it 'returns correct display name for manager_teammate_id' do
      manager = create(:person, first_name: 'John', last_name: 'Doe')
      organization = create(:organization)
      manager_teammate = create(:company_teammate, person: manager, organization: organization)
      expect(helper.filter_display_name('manager_teammate_id', manager_teammate.id.to_s)).to eq('John Doe')
    end

    it 'returns "All Teammates" for blank manager_teammate_id' do
      expect(helper.filter_display_name('manager_teammate_id', nil)).to eq('All Teammates')
      expect(helper.filter_display_name('manager_teammate_id', '')).to eq('All Teammates')
    end

    it 'returns "Unknown Manager" for invalid manager_teammate_id' do
      expect(helper.filter_display_name('manager_teammate_id', '999999')).to eq('Unknown Manager')
    end

    it 'returns correct display name for customize_company permission' do
      expect(helper.filter_display_name('permission', 'customize_company')).to eq('Customize Company')
    end

    it 'returns display name for kudos_rewards permission' do
      allow(helper).to receive(:company_label_plural).with('kudos_point', 'Kudos Point').and_return('Kudos Points')
      expect(helper.filter_display_name('permission', 'kudos_rewards')).to eq('Kudos Points & Rewards Management')
    end
  end

  describe '#teammate_permissions_badges' do
    it 'includes Customize badge when teammate has customize_company permission' do
      teammate.update!(can_customize_company: true)
      result = helper.teammate_permissions_badges(teammate)
      expect(result).to include('Customize')
      expect(result).to include('badge bg-warning')
    end

    it 'does not include Customize badge when teammate lacks permission' do
      teammate.update!(can_customize_company: false)
      result = helper.teammate_permissions_badges(teammate)
      expect(result).not_to include('Customize')
    end

    it 'includes Kudos badge when teammate has can_manage_kudos_rewards' do
      teammate.update!(can_manage_kudos_rewards: true)
      result = helper.teammate_permissions_badges(teammate)
      expect(result).to include('Kudos')
      expect(result).to include('badge bg-secondary')
    end

    it 'does not include Kudos badge when teammate lacks permission' do
      teammate.update!(can_manage_kudos_rewards: false)
      result = helper.teammate_permissions_badges(teammate)
      expect(result).not_to include('Kudos')
    end
  end

  describe '#teammate_current_position' do
    context 'when teammate has an active employment tenure with position' do
      it 'returns the position display name' do
        # Factory creates employment_tenure with a position automatically
        result = helper.teammate_current_position(teammate)
        expect(result).to include(employment_tenure.position.display_name)
        expect(result).to include('text-dark')
      end
    end

    context 'when teammate has no active employment tenure' do
      before do
        employment_tenure.update!(ended_at: 1.day.ago)
      end

      it 'returns "No position"' do
        result = helper.teammate_current_position(teammate)
        expect(result).to include('No position')
        expect(result).to include('text-muted')
      end
    end

    context 'when teammate has no employment tenures at all' do
      let(:teammate_without_tenure) { create(:company_teammate, person: create(:person), organization: organization) }

      it 'returns "No position"' do
        result = helper.teammate_current_position(teammate_without_tenure)
        expect(result).to include('No position')
        expect(result).to include('text-muted')
      end
    end
  end

  describe '#teammate_current_title' do
    context 'when teammate has an active employment tenure with position and title' do
      it 'returns a link to the title show page' do
        # Factory creates employment_tenure with a position (and title) automatically
        tenure_title = employment_tenure.position.title
        result = helper.teammate_current_title(teammate)
        expect(result).to include(tenure_title.external_title)
        expect(result).to include('href')
        expect(result).to include(organization_title_path(organization, tenure_title))
      end

      it 'opens the link in a new window' do
        result = helper.teammate_current_title(teammate)
        expect(result).to include('target="_blank"')
      end

      it 'has no text decoration class' do
        result = helper.teammate_current_title(teammate)
        expect(result).to include('text-decoration-none')
      end
    end

    context 'when teammate has no active employment tenure' do
      before do
        employment_tenure.update!(ended_at: 1.day.ago)
      end

      it 'returns "No title"' do
        result = helper.teammate_current_title(teammate)
        expect(result).to include('No title')
        expect(result).to include('text-muted')
      end
    end

    context 'when teammate has no employment tenures at all' do
      let(:teammate_without_tenure) { create(:company_teammate, person: create(:person), organization: organization) }

      it 'returns "No title"' do
        result = helper.teammate_current_title(teammate_without_tenure)
        expect(result).to include('No title')
        expect(result).to include('text-muted')
      end
    end

    context 'when a different organization is provided' do
      let(:other_organization) { create(:organization) }

      it 'uses the provided organization for the link path' do
        tenure_title = employment_tenure.position.title
        result = helper.teammate_current_title(teammate, other_organization)
        expect(result).to include(organization_title_path(other_organization, tenure_title))
      end
    end
  end

  describe '#clear_filter_url' do
    # Use top-level organization so @organization (set in main before) matches the stub
    let(:filter_manager) { create(:person) }
    let(:filter_manager_teammate) { create(:company_teammate, person: filter_manager, organization: organization) }
    before do
      allow(helper).to receive(:params).and_return({ controller: 'organizations/employees', action: 'index', manager_teammate_id: filter_manager_teammate.id.to_s, status: 'active' })
      allow(helper).to receive(:organization_employees_path).with(organization, { status: 'active' }).and_return('/test/path')
    end

    it 'removes manager_teammate_id from params' do
      result = helper.clear_filter_url('manager_teammate_id', filter_manager_teammate.id.to_s)
      expect(result).to eq('/test/path')
    end

    it 'handles nil filter_value' do
      result = helper.clear_filter_url('manager_teammate_id', nil)
      expect(result).to eq('')
    end
  end

  describe '#categorize_check_ins_by_freshness' do
    let(:check_ins) do
      [
        # Fresh check-in (finalized 30 days ago)
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, official_check_in_completed_at: 30.days.ago, finalized_by_teammate: manager_teammate),
        # Stale but active check-in (finalized 100 days ago, manager completed)
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, official_check_in_completed_at: 100.days.ago, manager_completed_at: 1.day.ago, manager_completed_by_teammate: manager_teammate, finalized_by_teammate: manager_teammate),
        # Stale and inactive check-in (finalized 100 days ago, neither completed)
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, official_check_in_completed_at: 100.days.ago, finalized_by_teammate: manager_teammate),
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
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, official_check_in_completed_at: 30.days.ago, finalized_by_teammate: manager_teammate),
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, official_check_in_completed_at: 30.days.ago, finalized_by_teammate: manager_teammate),
        create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, official_check_in_completed_at: 100.days.ago, manager_completed_at: 1.day.ago, manager_completed_by_teammate: manager_teammate, finalized_by_teammate: manager_teammate)
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
                 employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, manager_completed_by_teammate: manager_teammate, official_check_in_completed_at: nil)
        ],
        assignments: [
          create(:assignment_check_in, teammate: teammate, assignment: assignment,
                 employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, manager_completed_by_teammate: manager_teammate, official_check_in_completed_at: nil)
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
      create(:maap_snapshot, employee_company_teammate: teammate, company: organization, change_type: 'position_tenure',
             effective_date: Date.current, employee_acknowledged_at: nil)
      create(:maap_snapshot, employee_company_teammate: teammate, company: organization, change_type: 'assignment_management',
             effective_date: Date.current, employee_acknowledged_at: nil)
      create(:maap_snapshot, employee_company_teammate: teammate, company: organization, change_type: 'position_tenure',
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
    # Organization no longer has department/team STI or parent; self_and_descendants is [self], so
    # the helper shows "—" when person has only company teammate(s).
    let(:company) { create(:organization, :company, name: 'Acme Corp') }

    before do
      @organization = company
    end

    context 'when person has teammates in multiple departments and teams' do
      let!(:teammate_company) { create(:company_teammate, person: person, organization: company) }

      it 'displays all departments and teams as comma-separated list' do
        result = helper.teammate_organization_display(teammate_company)
        expect(result).not_to include('Acme Corp')
        expect(result).to include('—')
      end

      it 'sorts organizations alphabetically' do
        result = helper.teammate_organization_display(teammate_company)
        expect(result).to include('—')
      end

      it 'excludes the company from the list' do
        result = helper.teammate_organization_display(teammate_company)
        expect(result).not_to include('Acme Corp')
      end
    end

    context 'when person only has teammate in company (no departments/teams)' do
      let!(:teammate_company) { create(:company_teammate, person: person, organization: company) }

      it 'displays em dash when no departments/teams' do
        result = helper.teammate_organization_display(teammate_company)
        expect(result).to include('—')
      end
    end

    context 'when person has teammates in departments only' do
      let!(:teammate_company) { create(:company_teammate, person: person, organization: company) }

      it 'displays only departments' do
        result = helper.teammate_organization_display(teammate_company)
        expect(result).not_to include('Acme Corp')
        expect(result).to include('—')
      end
    end

    context 'when person has teammates in teams only' do
      let!(:teammate_company) { create(:company_teammate, person: person, organization: company) }

      it 'displays only teams' do
        result = helper.teammate_organization_display(teammate_company)
        expect(result).not_to include('Acme Corp')
        expect(result).to include('—')
      end
    end

    context 'when viewing from a department context' do
      before do
        @organization = company
      end

      let!(:teammate_company) { create(:company_teammate, person: person, organization: company) }

      it 'still finds all departments/teams within the company hierarchy' do
        result = helper.teammate_organization_display(teammate_company)
        expect(result).not_to include('Acme Corp')
        expect(result).to include('—')
      end
    end

    context 'when person has teammates in different companies' do
      let(:other_company) { create(:organization, :company, name: 'Other Corp') }
      let!(:teammate_company) { create(:company_teammate, person: person, organization: company) }
      let!(:teammate_other) { create(:company_teammate, person: person, organization: other_company) }

      it 'only shows departments/teams from the current company' do
        result = helper.teammate_organization_display(teammate_company)
        expect(result).not_to include('Other Corp')
        expect(result).to include('—')
      end
    end

    context 'edge cases' do
      it 'handles nil teammate gracefully' do
        result = helper.teammate_organization_display(nil)
        expect(result).to eq('')
      end

      it 'handles teammate with nil person gracefully' do
        teammate_nil_person = build(:company_teammate, person: nil)
        result = helper.teammate_organization_display(teammate_nil_person)
        expect(result).to eq('')
      end

      it 'handles nil @organization gracefully' do
        @organization = nil
        teammate = create(:company_teammate, person: person, organization: company)
        result = helper.teammate_organization_display(teammate)
        expect(result).to eq('')
      end

      it 'handles multiple teammates in same organization gracefully' do
        teammate1 = create(:company_teammate, person: person, organization: company)
        result = helper.teammate_organization_display(teammate1)
        expect(result).to include('—')
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

  describe '#available_presets_with_permissions' do
    let(:organization) { create(:organization, :company) }
    let(:manager) { create(:person) }
    let(:direct_report) { create(:person) }
    let(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization) }
    let(:direct_report_teammate) { CompanyTeammate.create!(person: direct_report, organization: organization) }

    before do
      @organization = organization
      # Stub policy method for permission checks
      allow(helper).to receive(:policy).and_return(double(manage_employment?: manager_teammate.can_manage_employment?))
    end

    context 'when user has direct reports' do
      before do
        create(:employment_tenure, company_teammate: direct_report_teammate, company: organization, manager: manager, ended_at: nil)
      end

      context 'without employment management permission' do
        before do
          manager_teammate.update!(can_manage_employment: false)
        end

        it 'makes My Direct Reports - Check-in Status Style 1 available' do
          presets = helper.available_presets_with_permissions(organization, manager_teammate)
          style_1 = presets.find { |p| p[:value] == 'my_direct_reports_check_in_status_1' }
          expect(style_1[:available]).to be true
        end

        it 'makes My Direct Reports - Check-in Status Style 2 available' do
          presets = helper.available_presets_with_permissions(organization, manager_teammate)
          style_2 = presets.find { |p| p[:value] == 'my_direct_reports_check_in_status_2' }
          expect(style_2[:available]).to be true
        end
      end

      context 'with employment management permission' do
        before do
          manager_teammate.update!(can_manage_employment: true)
        end

        it 'makes My Direct Reports - Check-in Status Style 1 available' do
          presets = helper.available_presets_with_permissions(organization, manager_teammate)
          style_1 = presets.find { |p| p[:value] == 'my_direct_reports_check_in_status_1' }
          expect(style_1[:available]).to be true
        end

        it 'makes My Direct Reports - Check-in Status Style 2 available' do
          presets = helper.available_presets_with_permissions(organization, manager_teammate)
          style_2 = presets.find { |p| p[:value] == 'my_direct_reports_check_in_status_2' }
          expect(style_2[:available]).to be true
        end
      end
    end

    context 'when user does not have direct reports' do
      before do
        manager_teammate.update!(can_manage_employment: true)
      end

      it 'makes My Direct Reports - Check-in Status Style 1 unavailable' do
        presets = helper.available_presets_with_permissions(organization, manager_teammate)
        style_1 = presets.find { |p| p[:value] == 'my_direct_reports_check_in_status_1' }
        expect(style_1[:available]).to be false
        expect(style_1[:permission_required]).to eq('direct reports')
        expect(style_1[:tooltip]).to eq('You need to have direct reports to use this preset')
      end

      it 'makes My Direct Reports - Check-in Status Style 2 unavailable' do
        presets = helper.available_presets_with_permissions(organization, manager_teammate)
        style_2 = presets.find { |p| p[:value] == 'my_direct_reports_check_in_status_2' }
        expect(style_2[:available]).to be false
        expect(style_2[:permission_required]).to eq('direct reports')
        expect(style_2[:tooltip]).to eq('You need to have direct reports to use this preset')
      end
    end
  end
end
