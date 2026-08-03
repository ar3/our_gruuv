# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyGrowth::ExperiencesSummary do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }
  let(:assignment_a) { create(:assignment, company: organization, title: 'Alpha Work') }
  let(:assignment_b) { create(:assignment, company: organization, title: 'Beta Work') }

  def build_summary(energy_by_assignment:, check_ins: {}, open: {})
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
      latest_finalized_check_ins_by_assignment_id: check_ins,
      open_check_ins_by_assignment_id: open
    )
  end

  describe '.for_teammate' do
    it 'loads latest finalized check-ins and builds summary data' do
      create(
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
        ended_at: nil,
        official_rating: 'exceeding'
      )

      summary = described_class.for_teammate(teammate.reload)

      expect(summary.total_energy_percentage).to eq(100)
      expect(summary.alert_band).to eq(:success)
      expect(summary.energy_by_rating_chart).to include(
        hash_including(name: 'Exceeding Expectations', y: 100)
      )
      expect(summary.show_inflight_rating_chart).to eq(true)
      expect(summary.energy_by_inflight_rating_chart).to include(
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

    it 'prefers employee-completed actual energy on the in-flight energy chart only' do
      create(
        :assignment_tenure,
        teammate: teammate,
        assignment: assignment_a,
        anticipated_energy_percentage: 40,
        ended_at: nil
      )
      open_a = create(
        :assignment_check_in,
        teammate: teammate,
        assignment: assignment_a,
        employee_completed_at: Time.current,
        actual_energy_percentage: 55,
        manager_completed_at: nil,
        official_check_in_completed_at: nil
      )

      summary = described_class.build(
        teammate: teammate.reload,
        latest_finalized_check_ins_by_assignment_id: {},
        open_check_ins_by_assignment_id: { assignment_a.id => open_a }
      )

      expect(summary.total_energy_percentage).to eq(40)
      expect(summary.energy_by_assignment_chart).to eq([{ name: 'Alpha Work', y: 40 }])
      expect(summary.energy_by_inflight_assignment_chart).to eq([{ name: 'Alpha Work', y: 55 }])
    end
  end

  describe 'energy_by_rating_chart' do
    it 'groups tenure energy by latest finalized official rating' do
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

  describe 'energy_by_inflight_rating_chart' do
    let(:manager_person) { create(:person) }
    let(:manager_teammate) { create(:teammate, person: manager_person, organization: organization) }

    before do
      create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil,
             manager_teammate: manager_teammate)
    end

    it 'uses manager-completed open rating with in-flight energy, else tenure official_rating' do
      create(
        :assignment_tenure,
        teammate: teammate,
        assignment: assignment_a,
        anticipated_energy_percentage: 40,
        ended_at: nil,
        official_rating: 'meeting'
      )
      create(
        :assignment_tenure,
        teammate: teammate,
        assignment: assignment_b,
        anticipated_energy_percentage: 60,
        ended_at: nil,
        official_rating: nil
      )
      open_a = create(
        :assignment_check_in,
        teammate: teammate,
        assignment: assignment_a,
        employee_completed_at: Time.current,
        actual_energy_percentage: 35,
        manager_completed_at: Time.current,
        manager_completed_by_teammate: manager_teammate,
        manager_rating: 'exceeding',
        official_check_in_completed_at: nil
      )

      summary = described_class.build(
        teammate: teammate.reload,
        latest_finalized_check_ins_by_assignment_id: {},
        open_check_ins_by_assignment_id: { assignment_a.id => open_a }
      )

      expect(summary.show_inflight_charts).to eq(true)
      expect(summary.energy_by_inflight_assignment_chart).to contain_exactly(
        hash_including(name: 'Alpha Work', y: 35),
        hash_including(name: 'Beta Work', y: 60)
      )
      expect(summary.energy_by_inflight_rating_chart).to contain_exactly(
        hash_including(name: 'Exceeding Expectations', y: 35),
        hash_including(name: 'No rating yet', y: 60)
      )
      expect(summary.energy_by_assignment_chart).to contain_exactly(
        hash_including(name: 'Alpha Work', y: 40),
        hash_including(name: 'Beta Work', y: 60)
      )
      expect(summary.energy_by_rating_chart).to contain_exactly(
        hash_including(name: 'No finalized check-in', y: 100)
      )
    end

    it 'falls back to tenure energy and tenure official_rating when open sides are incomplete' do
      create(
        :assignment_tenure,
        teammate: teammate,
        assignment: assignment_a,
        anticipated_energy_percentage: 100,
        ended_at: nil,
        official_rating: 'working_to_meet'
      )
      open_a = create(
        :assignment_check_in,
        teammate: teammate,
        assignment: assignment_a,
        employee_completed_at: nil,
        manager_completed_at: nil,
        official_check_in_completed_at: nil
      )

      summary = described_class.build(
        teammate: teammate.reload,
        latest_finalized_check_ins_by_assignment_id: {},
        open_check_ins_by_assignment_id: { assignment_a.id => open_a }
      )

      expect(summary.energy_by_inflight_rating_chart).to contain_exactly(
        hash_including(name: 'Working to Meet expectations', y: 100)
      )
    end
  end
end
