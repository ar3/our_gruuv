# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::AcknowledgementQueue do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  let(:teammate) { create(:company_teammate, person: employee, organization: organization, first_employed_at: 1.year.ago) }
  let!(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:aspiration) { create(:aspiration, company: organization) }

  it "returns only the latest finalized unacknowledged check-in per item" do
    create(:assignment_check_in, :officially_completed,
           teammate: teammate,
           assignment: assignment,
           official_check_in_completed_at: 2.weeks.ago)
    latest_assignment = create(:assignment_check_in, :officially_completed,
                               teammate: teammate,
                               assignment: assignment,
                               official_check_in_completed_at: 1.day.ago)
    aspiration_ci = create(:aspiration_check_in, :finalized, teammate: teammate, aspiration: aspiration)
    position_ci = create(:position_check_in, :closed, teammate: teammate, employment_tenure: employment_tenure)

    queue = described_class.for(teammate: teammate)

    expect(queue.assignment_check_ins.map(&:id)).to eq([latest_assignment.id])
    expect(queue.aspiration_check_ins.map(&:id)).to eq([aspiration_ci.id])
    expect(queue.position_check_in.id).to eq(position_ci.id)
  end

  it "omits items whose latest finalized check-in is already acknowledged" do
    create(:assignment_check_in, :officially_completed,
           teammate: teammate,
           assignment: assignment,
           official_check_in_completed_at: 1.day.ago,
             employee_acknowledged_at: Time.current)

    queue = described_class.for(teammate: teammate)

    expect(queue.assignment_check_ins).to be_empty
  end

  it "omits finalized check-ins where all ratings are blank or N/A-style" do
    check_in = create(:assignment_check_in, :officially_completed,
                      teammate: teammate,
                      assignment: assignment,
                      official_check_in_completed_at: 1.day.ago)
    check_in.update_columns(employee_rating: nil, manager_rating: "na", official_rating: "")

    queue = described_class.for(teammate: teammate)

    expect(queue.assignment_check_ins).to be_empty
    expect(described_class.pending_count_for(teammate: teammate)).to eq(0)
  end
end
