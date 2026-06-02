# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIns::AssignmentEnergyAllocationSummary do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }
  let(:assignment_active) { create(:assignment, company: organization, title: 'Active Role') }
  let(:assignment_other) { create(:assignment, company: organization, title: 'Side Project') }

  def build_summary(reflection_check_ins: [])
    described_class.for_bulk_check_in(
      teammate: teammate.reload,
      reflection_check_ins: reflection_check_ins,
      organization: organization
    )
  end

  describe 'planned segments (active tenures only)' do
    it 'sums anticipated energy and uses 1% display weight for 0% tenures' do
      create(
        :assignment_tenure,
        teammate: teammate,
        assignment: assignment_active,
        anticipated_energy_percentage: 60,
        ended_at: nil
      )
      create(
        :assignment_tenure,
        teammate: teammate,
        assignment: assignment_other,
        anticipated_energy_percentage: 0,
        ended_at: nil
      )

      summary = build_summary

      expect(summary.planned_total).to eq(60)
      zero_seg = summary.planned_segments.find { |s| s.assignment_id == assignment_other.id }
      expect(zero_seg.value).to eq(0)
      expect(zero_seg.display_weight).to eq(1)
    end

    it 'excludes ended tenures from the planned bar' do
      create(
        :assignment_tenure,
        teammate: teammate,
        assignment: assignment_active,
        anticipated_energy_percentage: 100,
        started_at: 3.months.ago,
        ended_at: 1.month.ago
      )

      summary = build_summary

      expect(summary.planned_segments).to be_empty
      expect(summary.planned_total).to eq(0)
    end
  end

  describe 'reflection segments' do
    before do
      create(
        :assignment_tenure,
        teammate: teammate,
        assignment: assignment_active,
        anticipated_energy_percentage: 50,
        ended_at: nil
      )
    end

    it 'includes positive actual energy from check-ins on the page' do
      check_in = create(
        :assignment_check_in,
        teammate: teammate,
        assignment: assignment_active,
        actual_energy_percentage: 40
      )

      summary = build_summary(reflection_check_ins: [check_in])

      expect(summary.reflection_total).to eq(40)
      expect(summary.reflection_segments.map(&:value)).to eq([40])
    end

    it 'omits unset and zero actual energy' do
      unset = create(:assignment_check_in, teammate: teammate, assignment: assignment_active, actual_energy_percentage: nil)
      zero = create(:assignment_check_in, teammate: teammate, assignment: assignment_other, actual_energy_percentage: 0)

      summary = build_summary(reflection_check_ins: [unset, zero])

      expect(summary.reflection_segments).to be_empty
      expect(summary.reflection_empty?).to be true
    end

    it 'assigns warning band for reflection total near 100%' do
      check_in = create(
        :assignment_check_in,
        teammate: teammate,
        assignment: assignment_active,
        actual_energy_percentage: 95
      )

      summary = build_summary(reflection_check_ins: [check_in])

      expect(summary.reflection_alert_band).to eq(CheckIns::AssignmentEnergyAllocationSummary::ALERT_WARNING)
    end
  end
end
