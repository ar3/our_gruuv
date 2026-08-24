# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::CheckInAcknowledgementsReport do
  let(:organization) { create(:organization) }
  let(:person) { create(:person, first_name: "Sam") }
  let(:teammate) { create(:company_teammate, person: person, organization: organization, first_employed_at: 1.year.ago) }
  let!(:employment) { create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago) }
  let(:assignment) { create(:assignment, company: organization, title: "Ack Report Assignment") }

  it "buckets finalized check-ins by acknowledgement status" do
    create(:assignment_check_in, :officially_completed,
           teammate: teammate,
           assignment: assignment,
           official_check_in_completed_at: 2.days.ago,
           employee_acknowledged_at: 1.day.ago,
           employee_acknowledgement: "agree",
           employee_acknowledgement_notes: "Yep")
    other_assignment = create(:assignment, company: organization, title: "Pending One")
    create(:assignment_check_in, :officially_completed,
           teammate: teammate,
           assignment: other_assignment,
           official_check_in_completed_at: 3.days.ago)
    disagree_assignment = create(:assignment, company: organization, title: "Disagree One")
    create(:assignment_check_in, :officially_completed,
           teammate: teammate,
           assignment: disagree_assignment,
           official_check_in_completed_at: 4.days.ago,
           employee_acknowledged_at: 1.day.ago,
           employee_acknowledgement: "disagree",
           employee_acknowledgement_notes: "No")

    result = described_class.call(
      organization: organization,
      teammate_ids: [teammate.id],
      range: 30.days.ago..Time.current
    )

    expect(result[:counts]).to eq(agree: 1, disagree: 1, unacknowledged: 1)
    expect(result[:total]).to eq(3)
    expect(result[:pie_chart_data].map { |p| p[:name] }).to contain_exactly("Agreed", "Unacknowledged", "Disagreed")
    expect(result[:rows].map(&:item_name)).to include("Ack Report Assignment", "Pending One", "Disagree One")
  end

  it "excludes check-ins outside the timeframe" do
    create(:assignment_check_in, :officially_completed,
           teammate: teammate,
           assignment: assignment,
           official_check_in_completed_at: 120.days.ago)

    result = described_class.call(
      organization: organization,
      teammate_ids: [teammate.id],
      range: 90.days.ago..Time.current
    )

    expect(result[:total]).to eq(0)
  end
end
