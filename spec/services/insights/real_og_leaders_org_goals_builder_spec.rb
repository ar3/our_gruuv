# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::RealOgLeadersOrgGoalsBuilder do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: company) }
  let!(:department) { create(:department, company: company, name: "Engineering") }
  let!(:team) { create(:team, company: company, name: "Platform", department: department) }

  def dept_goal!(attrs: {})
    create(
      :goal,
      :active,
      {
        owner: department,
        creator: teammate,
        company_id: company.id,
        goal_type: "qualitative_key_result",
        privacy_level: "everyone_in_company"
      }.merge(attrs)
    )
  end

  def team_goal!(attrs: {})
    create(
      :goal,
      :active,
      {
        owner: team,
        creator: teammate,
        company_id: company.id,
        goal_type: "qualitative_key_result",
        privacy_level: "everyone_in_company"
      }.merge(attrs)
    )
  end

  def personal_goal!
    create(
      :goal,
      :active,
      owner: teammate,
      creator: teammate,
      company_id: company.id,
      goal_type: "qualitative_key_result",
      privacy_level: "everyone_in_company"
    )
  end

  describe "#call" do
    it "attributes checks, connections, and completions to shared owners and stars all three" do
      goal = dept_goal!
      create(
        :goal_check_in,
        goal: goal,
        confidence_reporter: person,
        created_at: 2.days.ago,
        check_in_week_start: 2.days.ago.to_date.beginning_of_week(:monday)
      )
      create(
        :goal_association,
        goal: goal,
        associable: create(:assignment, company: company),
        created_at: 2.days.ago
      )
      goal.update!(completed_at: 1.day.ago, started_at: 2.weeks.ago)

      rows = described_class.new(company: company, range: 90.days.ago..Time.current).call
      row = rows.find { |r| r.owner_type == "Department" && r.owner_id == department.id }

      expect(row).to be_present
      expect(row.display_name).to include("Engineering")
      expect(row.owner_kind_label).to eq("Department")
      expect(row.has_all_three).to be true
      expect(row.confidence_check_count).to eq(1)
      expect(row.connection_count).to eq(1)
      expect(row.completion_count).to eq(1)
    end

    it "does not count personal goals toward shared board rows" do
      personal = personal_goal!
      create(
        :goal_check_in,
        goal: personal,
        confidence_reporter: person,
        created_at: 1.day.ago,
        check_in_week_start: Date.current.beginning_of_week(:monday)
      )
      create(
        :goal_association,
        goal: personal,
        associable: create(:ability, company: company),
        created_at: 1.day.ago
      )

      expect(described_class.new(company: company, range: nil).call).to be_empty
    end

    it "counts links between shared goals and personal goals as connected" do
      shared = team_goal!
      personal = personal_goal!
      create(:goal_link, parent: shared, child: personal, created_at: 1.day.ago)

      rows = described_class.new(company: company, range: nil).call
      row = rows.find { |r| r.owner_type == "Team" }
      expect(row.connection_count).to eq(1)
      expect(row.has_connection).to be true
    end

    it "sorts two signals above one signal" do
      # Department: confidence only (one signal)
      high = dept_goal!(attrs: { title: "High checks" })
      2.times do |i|
        create(
          :goal_check_in,
          goal: high,
          confidence_reporter: person,
          created_at: (i + 1).days.ago,
          check_in_week_start: (Date.current - (i + 1).weeks).beginning_of_week(:monday)
        )
      end

      # Team: confidence + connection (two signals)
      low = team_goal!(attrs: { title: "Two signals" })
      create(
        :goal_check_in,
        goal: low,
        confidence_reporter: person,
        created_at: 1.hour.ago,
        check_in_week_start: Date.current.beginning_of_week(:monday)
      )
      create(
        :goal_association,
        goal: low,
        associable: create(:aspiration, company: company),
        created_at: 1.day.ago
      )

      rows = described_class.new(company: company, range: nil).call
      expect(rows.map(&:owner_type)).to eq(%w[Team Department])
    end
  end
end
