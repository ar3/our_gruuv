# frozen_string_literal: true

require "rails_helper"

RSpec.describe Organizations::Debug::SetEmploymentEndDateService do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(
      :teammate,
      person: person,
      organization: organization,
      first_employed_at: 1.year.ago,
      last_terminated_at: nil
    )
  end
  let(:created_by) do
    create(:teammate, organization: organization, can_manage_employment: true, first_employed_at: 1.year.ago)
  end
  let(:position_major_level) { create(:position_major_level) }
  let(:title) { create(:title, company: organization, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }

  describe ".default_end_date_for" do
    it "uses last tenure ended_at when present" do
      create(
        :employment_tenure,
        teammate: teammate,
        company: organization,
        position: position,
        started_at: 6.months.ago,
        ended_at: 1.month.ago
      )

      expect(described_class.default_end_date_for(teammate, organization)).to eq(1.month.ago.to_date)
    end

    it "falls back to started_at when tenure is still active" do
      tenure = create(
        :employment_tenure,
        teammate: teammate,
        company: organization,
        position: position,
        started_at: 6.months.ago,
        ended_at: nil
      )

      expect(described_class.default_end_date_for(teammate, organization)).to eq(tenure.started_at.to_date)
    end
  end

  describe ".call" do
    it "ends an active last tenure and sets last_terminated_at" do
      tenure = create(
        :employment_tenure,
        teammate: teammate,
        company: organization,
        position: position,
        started_at: 6.months.ago,
        ended_at: nil
      )
      end_date = Date.current - 3.days

      result = described_class.call(
        organization: organization,
        teammate: teammate,
        end_date: end_date,
        created_by: created_by
      )

      expect(result.ok?).to be true
      expect(tenure.reload.ended_at.to_date).to eq(end_date)
      expect(teammate.reload.last_terminated_at).to eq(end_date)
    end

    it "updates ended_at and last_terminated_at when last tenure is already ended" do
      tenure = create(
        :employment_tenure,
        teammate: teammate,
        company: organization,
        position: position,
        started_at: 6.months.ago,
        ended_at: 2.months.ago
      )
      # Stale: teammate still looks employed
      teammate.update_columns(last_terminated_at: nil)
      end_date = 1.month.ago.to_date

      result = described_class.call(
        organization: organization,
        teammate: teammate,
        end_date: end_date,
        created_by: created_by
      )

      expect(result.ok?).to be true
      expect(tenure.reload.ended_at.to_date).to eq(end_date)
      expect(teammate.reload.last_terminated_at).to eq(end_date)
    end

    it "returns an error when teammate has no employment tenure" do
      result = described_class.call(
        organization: organization,
        teammate: teammate,
        end_date: Date.current,
        created_by: created_by
      )

      expect(result.ok?).to be false
      expect(result.error).to include("No employment tenure")
    end
  end
end
