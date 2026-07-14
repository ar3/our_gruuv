# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyGrowth::ExperiencesSummary do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }
  let(:assignment_a) { create(:assignment, company: organization, title: 'Alpha Work') }
  let(:assignment_b) { create(:assignment, company: organization, title: 'Beta Work') }

  def build_summary(energy_by_assignment:, check_ins: {})
    energy_by_assignment.each do |assignment, energy|
      create(
        :assignment_tenure,
        teammate: teammate,
        assignment: assignment,
        anticipated_energy_percentage: energy,
        ended_at: nil
      )
    end

    described_class.build(
      teammate: teammate.reload,
      latest_finalized_check_ins_by_assignment_id: check_ins
    )
  end

  describe '.for_teammate' do
    it 'loads latest finalized check-ins and builds summary data' do
      check_in = create(
        :assignment_check_in,
        :officially_completed,
        teammate: teammate,
        assignment: assignment_a,
        official_rating: 'exceeding'
      )
      create(
        :assignment_tenure,
        teammate: teammate,
        assignment: assignment_a,
        anticipated_energy_percentage: 100,
        ended_at: nil
      )

      summary = described_class.for_teammate(teammate.reload)

      expect(summary.total_energy_percentage).to eq(100)
      expect(summary.alert_band).to eq(:success)
      expect(summary.energy_by_rating_chart).to include(
        hash_including(name: 'Exceeding Expectations', y: 100)
      )
    end
  end

  describe 'alert_band' do
    it 'returns success at exactly 100%' do
      summary = build_summary(energy_by_assignment: { assignment_a => 60, assignment_b => 40 })
      expect(summary.alert_band).to eq(:success)
      expect(summary.total_energy_percentage).to eq(100)
    end

    it 'returns warning between 90 and 99' do
      summary = build_summary(energy_by_assignment: { assignment_a => 99 })
      expect(summary.alert_band).to eq(:warning)
    end

    it 'returns warning between 101 and 110' do
      summary = build_summary(energy_by_assignment: { assignment_a => 55, assignment_b => 46 })
      expect(summary.total_energy_percentage).to eq(101)
      expect(summary.alert_band).to eq(:warning)
    end

    it 'returns danger below 90' do
      summary = build_summary(energy_by_assignment: { assignment_a => 89 })
      expect(summary.alert_band).to eq(:danger)
    end

    it 'returns danger above 110' do
      summary = build_summary(energy_by_assignment: { assignment_a => 60, assignment_b => 55 })
      expect(summary.total_energy_percentage).to eq(115)
      expect(summary.alert_band).to eq(:danger)
    end

    it 'returns danger when no active tenures with energy' do
      summary = described_class.build(teammate: teammate, latest_finalized_check_ins_by_assignment_id: {})
      expect(summary.total_energy_percentage).to eq(0)
      expect(summary.alert_band).to eq(:danger)
    end
  end

  describe 'energy_by_assignment_chart' do
    it 'builds one slice per active tenure with energy' do
      summary = build_summary(energy_by_assignment: { assignment_a => 30, assignment_b => 70 })
      expect(summary.energy_by_assignment_chart).to contain_exactly(
        { name: 'Alpha Work', y: 30 },
        { name: 'Beta Work', y: 70 }
      )
    end

    it 'excludes zero-energy active tenures' do
      create(:assignment_tenure, teammate: teammate, assignment: assignment_a, anticipated_energy_percentage: 0, ended_at: nil)
      summary = build_summary(energy_by_assignment: { assignment_b => 50 })
      expect(summary.energy_by_assignment_chart).to eq([{ name: 'Beta Work', y: 50 }])
    end
  end

  describe 'energy_by_rating_chart' do
    it 'groups energy by latest finalized official rating' do
      check_in = create(
        :assignment_check_in,
        :officially_completed,
        teammate: teammate,
        assignment: assignment_a,
        official_rating: 'meeting'
      )
      summary = build_summary(
        energy_by_assignment: { assignment_a => 40, assignment_b => 60 },
        check_ins: { assignment_a.id => check_in }
      )

      expect(summary.energy_by_rating_chart).to contain_exactly(
        hash_including(name: 'Meeting expectations', y: 40, color: '#0d6efd'),
        hash_including(name: 'No finalized check-in', y: 60, color: '#6c757d')
      )
    end
  end

  describe 'energy_by_inflight_viewer_rating_chart' do
    let(:manager_person) { create(:person) }
    let(:manager_teammate) { create(:teammate, person: manager_person, organization: organization) }

    before do
      create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil,
             manager_teammate: manager_teammate)
    end

    def build_with_viewer(energy_by_assignment:, finalized: {}, open: {}, viewer:)
      energy_by_assignment.each do |assignment, energy|
        create(
          :assignment_tenure,
          teammate: teammate,
          assignment: assignment,
          anticipated_energy_percentage: energy,
          ended_at: nil
        )
      end

      described_class.build(
        teammate: teammate.reload,
        latest_finalized_check_ins_by_assignment_id: finalized,
        open_check_ins_by_assignment_id: open,
        viewer_teammate: viewer
      )
    end

    it 'hides the chart when the viewer has not completed any open side' do
      summary = build_with_viewer(
        energy_by_assignment: { assignment_a => 100 },
        viewer: teammate
      )

      expect(summary.show_inflight_viewer_rating_chart).to eq(false)
      expect(summary.energy_by_inflight_viewer_rating_chart).to eq([])
    end

    it 'swaps employee open ratings into the hybrid chart for the employee viewer' do
      finalized_a = create(
        :assignment_check_in,
        :officially_completed,
        teammate: teammate,
        assignment: assignment_a,
        official_rating: 'meeting'
      )
      open_a = create(
        :assignment_check_in,
        teammate: teammate,
        assignment: assignment_a,
        employee_completed_at: Time.current,
        employee_rating: 'exceeding',
        manager_completed_at: nil,
        official_check_in_completed_at: nil
      )
      open_b = create(
        :assignment_check_in,
        teammate: teammate,
        assignment: assignment_b,
        employee_completed_at: nil,
        employee_rating: nil,
        manager_completed_at: nil,
        official_check_in_completed_at: nil
      )

      summary = build_with_viewer(
        energy_by_assignment: { assignment_a => 40, assignment_b => 60 },
        finalized: { assignment_a.id => finalized_a },
        open: { assignment_a.id => open_a, assignment_b.id => open_b },
        viewer: teammate
      )

      expect(summary.show_inflight_viewer_rating_chart).to eq(true)
      expect(summary.energy_by_inflight_viewer_rating_chart).to contain_exactly(
        hash_including(name: 'Exceeding Expectations', y: 40),
        hash_including(name: 'No finalized check-in', y: 60)
      )
      expect(summary.energy_by_rating_chart).to contain_exactly(
        hash_including(name: 'Meeting expectations', y: 40),
        hash_including(name: 'No finalized check-in', y: 60)
      )
    end

    it 'swaps manager open ratings for a managerial viewer' do
      open_a = create(
        :assignment_check_in,
        teammate: teammate,
        assignment: assignment_a,
        employee_completed_at: nil,
        manager_completed_at: Time.current,
        manager_completed_by_teammate: manager_teammate,
        manager_rating: 'working_to_meet',
        official_check_in_completed_at: nil
      )

      summary = build_with_viewer(
        energy_by_assignment: { assignment_a => 55, assignment_b => 45 },
        open: { assignment_a.id => open_a },
        viewer: manager_teammate
      )

      expect(summary.show_inflight_viewer_rating_chart).to eq(true)
      expect(summary.energy_by_inflight_viewer_rating_chart).to contain_exactly(
        hash_including(name: 'Working to Meet expectations', y: 55),
        hash_including(name: 'No finalized check-in', y: 45)
      )
    end
  end
end
