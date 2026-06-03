# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIns::TenureBypassAssignmentEnergyAllocationSummary do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let(:assignment_active) { create(:assignment, company: organization, title: 'Active Core') }
  let(:assignment_new) { create(:assignment, company: organization, title: 'New Work') }

  def build_summary(assignments:, assignment_data:)
    described_class.for_tenure_bypass(
      teammate: teammate.reload,
      assignments: assignments,
      assignment_data: assignment_data,
      organization: organization
    )
  end

  describe 'current bar (active tenures only)' do
    it 'includes active tenure forecasts' do
      active = create(:assignment_tenure, teammate: teammate, assignment: assignment_active,
        anticipated_energy_percentage: 60, ended_at: nil)
      assignment_data = {
        assignment_active.id => { latest_tenure: active }
      }

      summary = build_summary(assignments: [assignment_active], assignment_data: assignment_data)

      expect(summary.current_total).to eq(60)
      expect(summary.current_segments.map(&:assignment_id)).to eq([assignment_active.id])
    end

    it 'uses employee actual when employee completed an open check-in' do
      active = create(:assignment_tenure, teammate: teammate, assignment: assignment_active,
        anticipated_energy_percentage: 50, ended_at: nil)
      check_in = create(
        :assignment_check_in,
        teammate: teammate,
        assignment: assignment_active,
        employee_completed_at: 2.days.ago,
        actual_energy_percentage: 35
      )
      assignment_data = { assignment_active.id => { latest_tenure: active } }

      summary = build_summary(assignments: [assignment_active], assignment_data: assignment_data)

      expect(summary.current_total).to eq(35)
      expect(summary.employee_actual_by_assignment_id[assignment_active.id]).to eq(35)
      expect(check_in).to be_open
    end
  end

  describe 'updated bar (table rows with % > 0)' do
    it 'includes active tenure % on the table row' do
      active = create(:assignment_tenure, teammate: teammate, assignment: assignment_active,
        anticipated_energy_percentage: 40, ended_at: nil)
      assignment_data = { assignment_active.id => { latest_tenure: active } }

      summary = build_summary(assignments: [assignment_active], assignment_data: assignment_data)

      expect(summary.updated_total).to eq(40)
      expect(summary.updated_forecast_by_assignment_id[assignment_active.id]).to eq(40)
    end

    it 'omits rows without active tenure from updated bar until % is set' do
      ended = create(:assignment_tenure, teammate: teammate, assignment: assignment_new,
        started_at: 2.months.ago, anticipated_energy_percentage: 30, ended_at: 1.month.ago)
      assignment_data = { assignment_new.id => { latest_tenure: ended } }

      summary = build_summary(assignments: [assignment_new], assignment_data: assignment_data)

      expect(summary.updated_total).to eq(0)
      expect(summary.updated_empty?).to eq(true)
    end
  end
end
