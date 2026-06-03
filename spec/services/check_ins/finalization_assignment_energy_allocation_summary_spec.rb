# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIns::FinalizationAssignmentEnergyAllocationSummary do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }
  let(:assignment_active) { create(:assignment, company: organization, title: 'Active Core') }
  let(:assignment_other) { create(:assignment, company: organization, title: 'Other Work') }

  def build_summary(check_ins: [])
    described_class.for_finalization(
      teammate: teammate.reload,
      assignment_check_ins: check_ins,
      organization: organization
    )
  end

  describe 'active tenure base (all active tenures on both bars)' do
    it 'includes every active tenure even without a check-in on the page' do
      create(:assignment_tenure, teammate: teammate, assignment: assignment_active, anticipated_energy_percentage: 60, ended_at: nil)
      create(:assignment_tenure, teammate: teammate, assignment: assignment_other, anticipated_energy_percentage: 40, ended_at: nil)

      summary = build_summary(check_ins: [])

      expect(summary.current_total).to eq(100)
      expect(summary.updated_total).to eq(100)
      expect(summary.current_segments.map(&:assignment_id)).to contain_exactly(assignment_active.id, assignment_other.id)
    end
  end

  describe 'current bar overrides' do
    before do
      create(:assignment_tenure, teammate: teammate, assignment: assignment_active, anticipated_energy_percentage: 50, ended_at: nil)
    end

    it 'uses employee actual when employee completed an open check-in' do
      check_in = create(
        :assignment_check_in,
        teammate: teammate,
        assignment: assignment_active,
        employee_completed_at: 2.days.ago,
        actual_energy_percentage: 40
      )

      summary = build_summary(check_ins: [check_in])

      expect(summary.current_total).to eq(40)
    end
  end

  describe 'updated bar' do
    before do
      create(:assignment_tenure, teammate: teammate, assignment: assignment_active, anticipated_energy_percentage: 50, ended_at: nil)
      create(:assignment_tenure, teammate: teammate, assignment: assignment_other, anticipated_energy_percentage: 50, ended_at: nil)
    end

    it 'matches current bar when not ready for finalization' do
      check_in = create(
        :assignment_check_in,
        teammate: teammate,
        assignment: assignment_active,
        employee_completed_at: 2.days.ago,
        actual_energy_percentage: 35
      )

      summary = build_summary(check_ins: [check_in])

      expect(summary.updated_total).to eq(summary.current_total)
      expect(summary.updated_forecast_by_assignment_id[assignment_active.id]).to eq(35)
      expect(summary.updated_forecast_by_assignment_id[assignment_other.id]).to eq(50)
    end

    it 'uses finalization energy for ready assignments (defaults to actual then tenure)' do
      ready = create(
        :assignment_check_in,
        :ready_for_finalization,
        teammate: teammate,
        assignment: assignment_active,
        actual_energy_percentage: 30
      )

      summary = build_summary(check_ins: [ready])

      expect(summary.current_segments.find { |s| s.assignment_id == assignment_active.id }.value).to eq(30)
      expect(summary.updated_forecast_by_assignment_id[assignment_active.id]).to eq(30)
      expect(summary.updated_forecast_by_assignment_id[assignment_other.id]).to eq(50)
      expect(summary.current_total).to eq(80)
      expect(summary.updated_total).to eq(80)
    end
  end
end
