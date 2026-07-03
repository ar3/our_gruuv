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
