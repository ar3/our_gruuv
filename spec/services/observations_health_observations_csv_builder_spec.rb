# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObservationsHealthObservationsCsvBuilder do
  let(:company) { create(:organization, :company) }
  let(:observer_person) { create(:person, first_name: "Alex", last_name: "Author") }
  let(:observee_person) { create(:person, first_name: "Riley", last_name: "Seen") }
  let(:observer_tm) { create(:teammate, person: observer_person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil) }
  let(:observee_tm) { create(:teammate, person: observee_person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil) }

  it "exports a Given row for authored published OGOs" do
    observation = create(
      :observation,
      company: company,
      observer: observer_person,
      story: "Quarterly feedback summary",
      privacy_level: :observed_only,
      observation_type: :feedback,
      published_at: 2.days.ago,
      deleted_at: nil
    )
    observation.observees.destroy_all
    create(:observee, observation: observation, teammate: observee_tm)

    csv = described_class.new(company, [observer_tm], current_person: observer_person).call
    lines = csv.lines.map(&:chomp)

    expect(lines.first).to include("Direction")
    expect(lines.first).to include("Health Employee Name")
    data_line = lines.find { |l| l.include?("Given") && l.include?(observation.id.to_s) }
    expect(data_line).to be_present
    expect(data_line).to include("Alex Author")
    expect(data_line).to include("Quarterly feedback summary")
  end

  it "exports a Received row when the teammate is an observee" do
    other_author = create(:person, first_name: "Sam", last_name: "Boss")
    create(:teammate, person: other_author, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)

    observation = create(
      :observation,
      company: company,
      observer: other_author,
      story: "Great collaboration",
      privacy_level: :observed_only,
      observation_type: :kudos,
      published_at: 1.day.ago,
      deleted_at: nil
    )
    observation.observees.destroy_all
    create(:observee, observation: observation, teammate: observee_tm)

    csv = described_class.new(company, [observee_tm], current_person: observee_person).call
    lines = csv.lines.map(&:chomp)
    data_line = lines.find { |l| l.include?("Received") && l.include?(observation.id.to_s) }
    expect(data_line).to be_present
    expect(data_line).to include("Riley Seen")
  end

  it "omits observed_only OGOs the downloader cannot see on the observations index" do
    manager_person = create(:person, first_name: "Morgan", last_name: "Manager")
    manager_tm = create(
      :teammate,
      person: manager_person,
      organization: company,
      first_employed_at: 1.month.ago,
      last_terminated_at: nil,
      can_manage_employment: true
    )
    create(
      :employment_tenure,
      company_teammate: observee_tm,
      company: company,
      manager_teammate: manager_tm,
      started_at: 2.months.ago
    )

    observation = create(
      :observation,
      company: company,
      observer: observer_person,
      story: "Private peer feedback",
      privacy_level: :observed_only,
      observation_type: :feedback,
      published_at: 1.day.ago,
      deleted_at: nil
    )
    observation.observees.destroy_all
    create(:observee, observation: observation, teammate: observee_tm)

    csv = described_class.new(company, [observee_tm], current_person: manager_person).call
    expect(csv).not_to include(observation.id.to_s)
    expect(csv).not_to include("Private peer feedback")
  end
end
