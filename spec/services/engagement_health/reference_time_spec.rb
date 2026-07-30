# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EngagementHealth::ReferenceTime do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let(:reference_time) { Time.zone.parse('2025-06-08 23:59:59') }

  around do |example|
    Time.use_zone('UTC') { example.run }
  end

  describe '.tenure_active_at?' do
    it 'is true when the tenure spans reference_time' do
      expect(
        described_class.tenure_active_at?(
          reference_time - 30.days,
          nil,
          reference_time
        )
      ).to be(true)
    end

    it 'is false when the tenure starts after reference_time' do
      expect(
        described_class.tenure_active_at?(
          reference_time + 1.day,
          nil,
          reference_time
        )
      ).to be(false)
    end

    it 'is false when the tenure ended on or before reference_time' do
      expect(
        described_class.tenure_active_at?(
          reference_time - 30.days,
          reference_time,
          reference_time
        )
      ).to be(false)
    end
  end

  describe '.employment_tenure_for' do
    it 'returns the employment tenure active at reference_time' do
      create(
        :employment_tenure,
        teammate: teammate,
        company: organization,
        started_at: reference_time - 2.years,
        ended_at: reference_time - 1.day
      )

      expect(described_class.employment_tenure_for(
        teammate: teammate,
        organization: organization,
        reference_time: reference_time
      )).to be_nil

      active_tenure = create(
        :employment_tenure,
        teammate: teammate,
        company: organization,
        started_at: reference_time - 1.year,
        ended_at: nil
      )

      expect(described_class.employment_tenure_for(
        teammate: teammate,
        organization: organization,
        reference_time: reference_time
      )).to eq(active_tenure)
    end
  end

  describe '.assignment_tenures_for' do
    it 'returns only assignment tenures active with energy at reference_time' do
      assignment = create(:assignment, company: organization)
      active = create(
        :assignment_tenure,
        teammate: teammate,
        assignment: assignment,
        started_at: reference_time - 30.days,
        ended_at: nil,
        anticipated_energy_percentage: 25
      )
      create(
        :assignment_tenure,
        teammate: teammate,
        assignment: create(:assignment, company: organization),
        started_at: reference_time - 30.days,
        ended_at: reference_time - 1.day,
        anticipated_energy_percentage: 25
      )
      create(
        :assignment_tenure,
        teammate: teammate,
        assignment: create(:assignment, company: organization),
        started_at: reference_time + 1.day,
        ended_at: nil,
        anticipated_energy_percentage: 25
      )

      ids = described_class.assignment_tenures_for(
        teammate: teammate,
        organization: organization,
        reference_time: reference_time
      ).map(&:id)

      expect(ids).to eq([active.id])
    end
  end

  describe '.consecutive_positive_energy_tenure_started_at' do
    let(:assignment) { create(:assignment, company: organization) }

    def tenure(started_at:, ended_at:, energy: 40)
      create(
        :assignment_tenure,
        teammate: teammate,
        assignment: assignment,
        started_at: started_at,
        ended_at: ended_at,
        anticipated_energy_percentage: energy
      )
    end

    it 'returns nil when no positive-energy tenure is active at reference_time' do
      tenure(started_at: reference_time - 40.days, ended_at: reference_time - 1.day)
      history = described_class.positive_energy_assignment_tenures_history(
        teammate: teammate,
        assignment_id: assignment.id,
        reference_time: reference_time
      )

      expect(
        described_class.consecutive_positive_energy_tenure_started_at(history, reference_time: reference_time)
      ).to be_nil
    end

    it 'uses the earliest start in a no-gap consecutive chain' do
      chain_start = (reference_time - 45.days).to_date
      mid = (reference_time - 20.days).to_date
      tenure(started_at: chain_start, ended_at: mid, energy: 25)
      tenure(started_at: mid, ended_at: nil, energy: 60)
      history = described_class.positive_energy_assignment_tenures_history(
        teammate: teammate,
        assignment_id: assignment.id,
        reference_time: reference_time
      )

      expect(
        described_class.consecutive_positive_energy_tenure_started_at(history, reference_time: reference_time)
      ).to eq(chain_start)
    end

    it 'treats adjacent calendar days as consecutive (no gap)' do
      first_start = (reference_time - 30.days).to_date
      first_end = (reference_time - 15.days).to_date
      second_start = first_end + 1.day
      tenure(started_at: first_start, ended_at: first_end, energy: 25)
      tenure(started_at: second_start, ended_at: nil, energy: 40)
      history = described_class.positive_energy_assignment_tenures_history(
        teammate: teammate,
        assignment_id: assignment.id,
        reference_time: reference_time
      )

      expect(
        described_class.consecutive_positive_energy_tenure_started_at(history, reference_time: reference_time)
      ).to eq(first_start)
    end

    it 'breaks the chain on any calendar gap' do
      old_start = (reference_time - 50.days).to_date
      tenure(started_at: old_start, ended_at: reference_time - 20.days, energy: 25)
      new_start = (reference_time - 10.days).to_date
      tenure(started_at: new_start, ended_at: nil, energy: 40)
      history = described_class.positive_energy_assignment_tenures_history(
        teammate: teammate,
        assignment_id: assignment.id,
        reference_time: reference_time
      )

      expect(
        described_class.consecutive_positive_energy_tenure_started_at(history, reference_time: reference_time)
      ).to eq(new_start)
    end

    it 'does not let 0% energy tenures bridge or extend the chain' do
      old_start = (reference_time - 50.days).to_date
      tenure(started_at: old_start, ended_at: reference_time - 20.days, energy: 25)
      tenure(started_at: reference_time - 20.days, ended_at: reference_time - 10.days, energy: 0)
      new_start = (reference_time - 10.days).to_date
      tenure(started_at: new_start, ended_at: nil, energy: 40)
      history = described_class.positive_energy_assignment_tenures_history(
        teammate: teammate,
        assignment_id: assignment.id,
        reference_time: reference_time
      )

      expect(history.map(&:anticipated_energy_percentage)).to all(be > 0)
      expect(
        described_class.consecutive_positive_energy_tenure_started_at(history, reference_time: reference_time)
      ).to eq(new_start)
    end
  end

  describe '.aspirations_for' do
    it 'excludes aspirations created or deleted after reference_time' do
      current = create(:aspiration, company: organization, created_at: reference_time - 1.year)
      create(:aspiration, company: organization, created_at: reference_time + 1.day)
      deleted_later = create(:aspiration, company: organization, created_at: reference_time - 1.year)
      deleted_later.update_columns(deleted_at: reference_time + 1.day)

      ids = described_class.aspirations_for(
        organization: organization,
        reference_time: reference_time
      ).pluck(:id)

      expect(ids).to contain_exactly(current.id, deleted_later.id)
    end
  end
end
