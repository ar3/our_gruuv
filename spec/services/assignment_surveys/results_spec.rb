require "rails_helper"

RSpec.describe AssignmentSurveys::Results do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, :assigned_employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }

  it "uses only each teammate's latest submitted response per assignment in aggregates" do
    create(
      :assignment_survey_response,
      company_teammate: teammate,
      assignment: assignment,
      understandable_rating: 1,
      possible_rating: 1,
      relevant_rating: 1,
      submitted_at: 2.days.ago
    )
    create(
      :assignment_survey_response,
      company_teammate: teammate,
      assignment: assignment,
      understandable_rating: 6,
      possible_rating: 5,
      relevant_rating: 4,
      submitted_at: 1.day.ago
    )

    results = described_class.new(
      organization: organization,
      teammates: CompanyTeammate.where(id: teammate.id)
    )

    understandable = results.overall_distributions.fetch(:understandable)
    expect(understandable[:total]).to eq(1)
    expect(understandable[:counts].fetch(1)).to eq(0)
    expect(understandable[:counts].fetch(6)).to eq(1)
    expect(understandable[:rating_sets].fetch(6)).to eq(teammate_count: 1, assignment_count: 1)
    expect(results.participation_rows.first[:response_count]).to eq(2)
  end

  it "counts distinct teammates and assignments in each rating set" do
    other_teammate = create(:teammate, :assigned_employee, organization: organization)
    other_assignment = create(:assignment, company: organization)

    [ teammate, other_teammate ].each do |survey_teammate|
      [ assignment, other_assignment ].each do |rated_assignment|
        create(
          :assignment_survey_response,
          :complete,
          company_teammate: survey_teammate,
          assignment: rated_assignment,
          understandable_rating: 6,
          possible_rating: rated_assignment == assignment ? 5 : 3,
          relevant_rating: rated_assignment == assignment ? 4 : 2
        )
      end
    end

    results = described_class.new(
      organization: organization,
      teammates: CompanyTeammate.where(id: [ teammate.id, other_teammate.id ])
    )

    understandable = results.overall_distributions.fetch(:understandable)
    expect(understandable[:counts].fetch(6)).to eq(4)
    expect(understandable[:rating_sets].fetch(6)).to eq(teammate_count: 2, assignment_count: 2)

    assignment_row = results.assignment_rows.find { |row| row[:assignment_id] == assignment.id }
    expect(assignment_row[:distributions].dig(:understandable, :average)).to eq(6.0)
    expect(assignment_row[:distributions].dig(:possible, :average)).to eq(5.0)
    expect(assignment_row[:distributions].dig(:relevant, :average)).to eq(4.0)
    expect(assignment_row[:overall_average]).to eq(5.0)
  end

  it "aggregates personal alignment on the 1/3/5/6 scale" do
    create(
      :assignment_survey_response,
      :complete,
      company_teammate: teammate,
      assignment: assignment,
      personal_alignment: "only_if_necessary"
    )
    other = create(:teammate, :assigned_employee, organization: organization)
    create(
      :assignment_survey_response,
      :complete,
      company_teammate: other,
      assignment: assignment,
      personal_alignment: "love"
    )

    results = described_class.new(
      organization: organization,
      teammates: CompanyTeammate.where(id: [ teammate.id, other.id ])
    )

    alignment = results.assignment_rows.find { |row| row[:assignment_id] == assignment.id }
      .fetch(:distributions)
      .fetch(:personal_alignment)

    expect(alignment[:counts]).to eq({ 1 => 1, 3 => 0, 5 => 0, 6 => 1 })
    expect(alignment[:average]).to eq(3.5)
    expect(alignment[:total]).to eq(2)
  end

  describe "assignment sort" do
    let(:alpha) { create(:assignment, company: organization, title: "Alpha role") }
    let(:middle) { create(:assignment, company: organization, title: "Middle role") }
    let(:zeta) { create(:assignment, company: organization, title: "Zeta role") }

    before do
      other = create(:teammate, :assigned_employee, organization: organization)

      [ alpha, middle, zeta ].each do |rated_assignment|
        create(
          :assignment_survey_response,
          :complete,
          company_teammate: teammate,
          assignment: rated_assignment,
          snapshot_title: rated_assignment.title,
          understandable_rating: rated_assignment == alpha ? 4 : (rated_assignment == middle ? 2 : 6),
          possible_rating: rated_assignment == alpha ? 4 : (rated_assignment == middle ? 2 : 6),
          relevant_rating: rated_assignment == alpha ? 4 : (rated_assignment == middle ? 2 : 6)
        )
      end

      create(
        :assignment_survey_response,
        :complete,
        company_teammate: other,
        assignment: middle,
        snapshot_title: middle.title,
        understandable_rating: 1,
        possible_rating: 1,
        relevant_rating: 1
      )
    end

    def titles_for(sort)
      described_class.new(
        organization: organization,
        teammates: CompanyTeammate.where(id: organization.company_teammates.select(:id)),
        assignment_sort: sort
      ).assignment_rows.map { |row| row[:title] }
    end

    it "defaults to alphabetical name order" do
      expect(titles_for("name")).to eq([ "Alpha role", "Middle role", "Zeta role" ])
      expect(titles_for("bogus")).to eq([ "Alpha role", "Middle role", "Zeta role" ])
    end

    it "sorts by overall average lowest first" do
      expect(titles_for("average")).to eq([ "Middle role", "Alpha role", "Zeta role" ])
    end

    it "sorts by response count highest first" do
      expect(titles_for("responses")).to eq([ "Middle role", "Alpha role", "Zeta role" ])
    end
  end

  it "uses org-wide responses for maintained assignment score cards" do
    other = create(:teammate, :assigned_employee, organization: organization)
    other_assignment = create(:assignment, company: organization, title: "Other role")

    [ teammate, other ].each do |survey_teammate|
      create(
        :assignment_survey_response,
        :complete,
        company_teammate: survey_teammate,
        assignment: assignment,
        snapshot_title: assignment.title
      )
      create(
        :assignment_survey_response,
        :complete,
        company_teammate: survey_teammate,
        assignment: other_assignment,
        snapshot_title: other_assignment.title,
        understandable_rating: 1,
        possible_rating: 1,
        relevant_rating: 1
      )
    end

    results = described_class.new(
      organization: organization,
      teammates: CompanyTeammate.where(id: teammate.id),
      maintained_assignment_ids: [ assignment.id ]
    )

    maintained_row = results.assignment_rows.find { |row| row[:assignment_id] == assignment.id }
    other_row = results.assignment_rows.find { |row| row[:assignment_id] == other_assignment.id }

    expect(maintained_row[:org_wide]).to eq(true)
    expect(maintained_row[:response_count]).to eq(2)
    expect(other_row[:org_wide]).to eq(false)
    expect(other_row[:response_count]).to eq(1)
  end
end
