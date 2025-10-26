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
      # Create closed check-in
      closed_check_in = create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure, employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, closed_at: 1.day.ago)
      
      result = helper.check_ins_for_employee(person, organization)

      expect(result[:position]).not_to include(closed_check_in)
    end

    it 'only includes active employment tenures' do
      # Create ended employment tenure
      ended_tenure = create(:employment_tenure, teammate: teammate, company: organization, ended_at: 1.day.ago)
      ended_check_in = create(:position_check_in, teammate: teammate, employment_tenure: ended_tenure, employee_completed_at: 1.day.ago, manager_completed_at: nil)
      
      result = helper.check_ins_for_employee(person, organization)

      expect(result[:position]).not_to include(ended_check_in)
    end

    it 'only includes active assignment tenures' do
      # Create ended assignment tenure
      ended_assignment_tenure = create(:assignment_tenure, teammate: teammate, assignment: assignment, ended_at: 1.day.ago)
      ended_check_in = create(:assignment_check_in, teammate: teammate, assignment: assignment, employee_completed_at: 1.day.ago, manager_completed_at: nil)
      
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

    it 'returns assignment name for AssignmentCheckIn' do
      assignment = build(:assignment, name: 'Project Alpha')
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
      allow(helper).to receive(:@organization).and_return(organization)
      result = helper.clear_filter_url('manager_filter', 'direct_reports')
      expect(result).to eq('/test/path')
    end

    it 'handles nil filter_value' do
      allow(helper).to receive(:@organization).and_return(organization)
      result = helper.clear_filter_url('manager_filter', nil)
      expect(result).to eq('/test/path')
    end
  end
end
