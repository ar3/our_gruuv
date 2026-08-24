# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::AcknowledgeCheckInService do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  let(:teammate) { create(:company_teammate, person: employee, organization: organization, first_employed_at: 1.year.ago) }
  let!(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago) }

  describe ".call" do
    context "with an assignment check-in" do
      let(:assignment) { create(:assignment, company: organization) }
      let!(:older) do
        create(:assignment_check_in, :officially_completed,
               teammate: teammate,
               assignment: assignment,
               official_check_in_completed_at: 2.weeks.ago)
      end
      let!(:latest) do
        create(:assignment_check_in, :officially_completed,
               teammate: teammate,
               assignment: assignment,
               official_check_in_completed_at: 1.day.ago)
      end

      it "acknowledges agree with optional notes on the latest finalized check-in" do
        result = described_class.call(
          teammate: teammate,
          check_in_type: "assignment",
          check_in_id: latest.id,
          acknowledgement: "acknowledge",
          notes: "Looks right"
        )

        expect(result).to be_ok
        latest.reload
        expect(latest.employee_acknowledged_at).to be_present
        expect(latest).to be_employee_acknowledged
        expect(latest.employee_acknowledgement_notes).to eq("Looks right")
      end

      it "rejects acknowledging an older finalized check-in" do
        result = described_class.call(
          teammate: teammate,
          check_in_type: "assignment",
          check_in_id: older.id,
          acknowledgement: "acknowledge"
        )

        expect(result).not_to be_ok
        expect(result.error).to include("latest finalized")
        expect(older.reload.employee_acknowledged_at).to be_nil
      end

      it "rejects changing an already acknowledged check-in" do
        described_class.call(
          teammate: teammate,
          check_in_type: "assignment",
          check_in_id: latest.id,
          acknowledgement: "acknowledge"
        )

        result = described_class.call(
          teammate: teammate,
          check_in_type: "assignment",
          check_in_id: latest.id,
          acknowledgement: "acknowledge",
          notes: "changed mind"
        )

        expect(result).not_to be_ok
        expect(latest.reload).to be_employee_acknowledged
        expect(latest.employee_acknowledgement_notes).to be_nil
      end

      it "rejects check-ins with no real ratings" do
        latest.update_columns(employee_rating: nil, manager_rating: nil, official_rating: nil)

        result = described_class.call(
          teammate: teammate,
          check_in_type: "assignment",
          check_in_id: latest.id,
          acknowledgement: "acknowledge"
        )

        expect(result).not_to be_ok
        expect(result.error).to include("no ratings")
      end
    end
  end
end
