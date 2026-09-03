# frozen_string_literal: true

require "rails_helper"

RSpec.describe Aspirations::ExpectationAlignmentScore do
  let(:organization) { create(:organization) }
  let(:aspiration) { create(:aspiration, company: organization) }
  let(:viewer) { create(:teammate, :assigned_employee, organization: organization, can_manage_maap: true) }
  let(:reference_time) { Time.zone.parse("2026-09-03 12:00:00") }

  def create_employee
    teammate = create(:teammate, :assigned_employee, organization: organization)
    create(:employment_tenure, company_teammate: teammate, company: organization)
    teammate
  end

  def create_finalized_check_in(teammate:, finalized_at:, employee_rating:, manager_rating:)
    create(
      :aspiration_check_in,
      :finalized,
      teammate: teammate,
      aspiration: aspiration,
      employee_rating: employee_rating,
      manager_rating: manager_rating,
      official_rating: manager_rating,
      official_check_in_completed_at: finalized_at
    )
  end

  before do
    create(:employment_tenure, company_teammate: viewer, company: organization)
  end

  describe ".recalculate!" do
    it "persists a weighted agreement-only score" do
      a = create_employee
      b = create_employee
      create_finalized_check_in(
        teammate: a,
        finalized_at: reference_time - 10.days,
        employee_rating: "meeting",
        manager_rating: "meeting"
      )
      create_finalized_check_in(
        teammate: b,
        finalized_at: reference_time - 10.days,
        employee_rating: "meeting",
        manager_rating: "exceeding"
      )

      record = described_class.recalculate!(aspiration: aspiration, reference_time: reference_time)

      expect(record.score.to_f).to eq(50.0)
      expect(record.check_in_teammate_count).to eq(2)
      expect(record.cells.size).to eq(3)
    end
  end

  describe ".for_viewer" do
    it "shows uncalculated state only to MAAP managers" do
      regular = create(:teammate, :assigned_employee, organization: organization, can_manage_maap: false)
      create(:employment_tenure, company_teammate: regular, company: organization)

      privileged = described_class.for_viewer(
        aspiration: aspiration,
        viewer: viewer,
        organization: organization
      )
      public_view = described_class.for_viewer(
        aspiration: aspiration,
        viewer: regular,
        organization: organization
      )

      expect(privileged.show_card?).to be(true)
      expect(privileged.can_refresh?).to be(true)
      expect(public_view.show_card?).to be(false)
    end

    it "shows the score to non-MAAP viewers when two teammates qualify" do
      a = create_employee
      b = create_employee
      create_finalized_check_in(
        teammate: a,
        finalized_at: reference_time - 5.days,
        employee_rating: "meeting",
        manager_rating: "meeting"
      )
      create_finalized_check_in(
        teammate: b,
        finalized_at: reference_time - 5.days,
        employee_rating: "meeting",
        manager_rating: "meeting"
      )
      described_class.recalculate!(aspiration: aspiration, reference_time: reference_time)

      regular = create(:teammate, :assigned_employee, organization: organization, can_manage_maap: false)
      create(:employment_tenure, company_teammate: regular, company: organization)

      result = described_class.for_viewer(
        aspiration: aspiration,
        viewer: regular,
        organization: organization
      )

      expect(result.can_see_score?).to be(true)
      expect(result.score).to eq(100.0)
    end
  end
end
