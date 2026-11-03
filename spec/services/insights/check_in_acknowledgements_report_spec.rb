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
           employee_acknowledgement_notes: "Yep")
    other_assignment = create(:assignment, company: organization, title: "Pending One")
    create(:assignment_check_in, :officially_completed,
           teammate: teammate,
           assignment: other_assignment,
           official_check_in_completed_at: 3.days.ago)

    result = described_class.call(
      organization: organization,
      teammate_ids: [teammate.id],
      range: 30.days.ago..Time.current
    )

    expect(result[:counts]).to eq(acknowledged: 1, unacknowledged: 1, skipped: 0)
    expect(result[:total]).to eq(2)
    expect(result[:pie_chart_data].map { |p| p[:name] }).to contain_exactly("Acknowledged", "Unacknowledged")
    expect(result[:rows].map(&:item_name)).to include("Ack Report Assignment", "Pending One")
  end

  it "marks older unacknowledged finalized check-ins as Skipped Ack" do
    create(:assignment_check_in, :officially_completed,
           teammate: teammate,
           assignment: assignment,
           official_check_in_completed_at: 20.days.ago,
           employee_acknowledged_at: nil)
    create(:assignment_check_in, :officially_completed,
           teammate: teammate,
           assignment: assignment,
           official_check_in_completed_at: 2.days.ago,
           employee_acknowledged_at: nil)

    result = described_class.call(
      organization: organization,
      teammate_ids: [teammate.id],
      range: 30.days.ago..Time.current
    )

    expect(result[:counts]).to eq(acknowledged: 0, unacknowledged: 1, skipped: 1)
    statuses_by_date = result[:rows].sort_by(&:finalized_at).map(&:status)
    expect(statuses_by_date).to eq([:skipped, :unacknowledged])
    expect(result[:rows].find { |r| r.status == :skipped }.status_label).to eq("Skipped Ack")
  end

  it "excludes check-ins with no real ratings" do
    create(:assignment_check_in, :officially_completed,
           teammate: teammate,
           assignment: assignment,
           official_check_in_completed_at: 2.days.ago,
           employee_rating: nil,
           manager_rating: nil,
           official_rating: nil)

    result = described_class.call(
      organization: organization,
      teammate_ids: [teammate.id],
      range: 30.days.ago..Time.current
    )

    expect(result[:total]).to eq(0)
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

  it "filters table rows by acknowledgement status while keeping overall counts" do
    create(:assignment_check_in, :officially_completed,
           teammate: teammate,
           assignment: assignment,
           official_check_in_completed_at: 2.days.ago,
           employee_acknowledged_at: 1.day.ago)
    other_assignment = create(:assignment, company: organization, title: "Still Waiting")
    create(:assignment_check_in, :officially_completed,
           teammate: teammate,
           assignment: other_assignment,
           official_check_in_completed_at: 3.days.ago)

    result = described_class.call(
      organization: organization,
      teammate_ids: [teammate.id],
      range: 30.days.ago..Time.current,
      status_filter: "unacknowledged"
    )

    expect(result[:total]).to eq(2)
    expect(result[:filtered_total]).to eq(1)
    expect(result[:counts]).to eq(acknowledged: 1, unacknowledged: 1, skipped: 0)
    expect(result[:rows].map(&:item_name)).to eq(["Still Waiting"])
  end

  it "includes teammate and manager names on each row" do
    manager_person = create(:person, first_name: "Mo", last_name: "Manager")
    manager_teammate = create(:company_teammate, person: manager_person, organization: organization, first_employed_at: 1.year.ago)
    employment.update!(manager_teammate: manager_teammate)
    create(:assignment_check_in, :officially_completed,
           teammate: teammate,
           assignment: assignment,
           official_check_in_completed_at: 2.days.ago,
           employee_acknowledged_at: 1.day.ago)

    result = described_class.call(
      organization: organization,
      teammate_ids: [teammate.id],
      range: 30.days.ago..Time.current
    )

    row = result[:rows].first
    expect(row.teammate_name).to eq(person.display_name)
    expect(row.manager_name).to eq(manager_person.casual_name)
  end

  it "includes a one-by-one check-in path for the item" do
    create(:assignment_check_in, :officially_completed,
           teammate: teammate,
           assignment: assignment,
           official_check_in_completed_at: 2.days.ago,
           employee_acknowledged_at: 1.day.ago)

    result = described_class.call(
      organization: organization,
      teammate_ids: [teammate.id],
      range: 30.days.ago..Time.current
    )

    expect(result[:rows].first.item_path).to eq(
      "#{Rails.application.routes.url_helpers.organization_teammate_assignment_path(organization, teammate, assignment)}#research-all-check-ins"
    )
  end
end
