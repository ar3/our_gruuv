# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::RealOgLeadersGoalsBuilder do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person, first_name: "Alex", last_name: "Goals") }
  let!(:teammate) { create(:teammate, person: person, organization: company) }
  let(:other) { create(:person, first_name: "Other", last_name: "Owner") }
  let!(:other_teammate) { create(:teammate, person: other, organization: company) }

  def personal_goal!(owner: teammate, attrs: {})
    create(
      :goal,
      :active,
      {
        owner: owner,
        creator: owner,
        company_id: company.id,
        goal_type: "qualitative_key_result",
        privacy_level: "everyone_in_company"
      }.merge(attrs)
    )
  end

  def org_goal!
    create(
      :goal,
      :active,
      owner: company,
      creator: teammate,
      company_id: company.id,
      goal_type: "inspirational_objective",
      privacy_level: "everyone_in_company",
      most_likely_target_date: nil,
      earliest_target_date: nil,
      latest_target_date: nil
    )
  end

  describe "#call" do
    it "counts confidence checks by reporter and stars all three signals" do
      goal = personal_goal!
      create(
        :goal_check_in,
        goal: goal,
        confidence_reporter: person,
        created_at: 2.days.ago,
        check_in_week_start: 2.days.ago.beginning_of_week(:monday)
      )
      assignment = create(:assignment, company: company)
      create(:goal_association, goal: goal, associable: assignment, created_at: 2.days.ago)
      goal.update!(completed_at: 1.day.ago, started_at: 2.weeks.ago)

      rows = described_class.new(company: company, range: 90.days.ago..Time.current).call
      row = rows.find { |r| r.person == person }

      expect(row).to be_present
      expect(row.has_confidence_check).to be true
      expect(row.has_connection).to be true
      expect(row.has_completion).to be true
      expect(row.has_all_three).to be true
      expect(row.confidence_check_count).to eq(1)
      expect(row.connection_count).to eq(1)
      expect(row.completion_count).to eq(1)
    end

    it "does not count personal-to-personal goal links as connected" do
      own = personal_goal!
      peer = personal_goal!(owner: other_teammate)
      create(:goal_link, parent: own, child: peer, created_at: 1.day.ago)

      rows = described_class.new(company: company, range: nil).call
      expect(rows).to be_empty
    end

    it "counts links to org/team/department goals as connected" do
      own = personal_goal!
      org = org_goal!
      create(:goal_link, parent: org, child: own, created_at: 1.day.ago)

      rows = described_class.new(company: company, range: nil).call
      row = rows.find { |r| r.person == person }
      expect(row.has_connection).to be true
      expect(row.connection_count).to eq(1)
      expect(row.has_confidence_check).to be false
      expect(row.has_completion).to be false
    end

    it "counts prompt connections" do
      goal = personal_goal!
      template = create(:prompt_template, company: company)
      prompt = create(:prompt, company_teammate: teammate, prompt_template: template)
      create(:prompt_goal, prompt: prompt, goal: goal, created_at: 1.day.ago)

      rows = described_class.new(company: company, range: nil).call
      expect(rows.first.connection_count).to eq(1)
    end

    it "counts aspiration associations as connected" do
      goal = personal_goal!
      create(
        :goal_association,
        goal: goal,
        associable: create(:aspiration, company: company),
        created_at: 1.day.ago
      )

      rows = described_class.new(company: company, range: nil).call
      expect(rows.first.connection_count).to eq(1)
      expect(rows.first.has_connection).to be true
    end

    it "sorts all-three first, then singles by confidence over connection" do
      all_person = create(:person, first_name: "All", last_name: "Three")
      all_tm = create(:teammate, person: all_person, organization: company)
      conf_person = create(:person, first_name: "Conf", last_name: "Only")
      conf_tm = create(:teammate, person: conf_person, organization: company)
      conn_person = create(:person, first_name: "Conn", last_name: "Only")
      conn_tm = create(:teammate, person: conn_person, organization: company)

      g_all = personal_goal!(owner: all_tm)
      create(
        :goal_check_in,
        goal: g_all,
        confidence_reporter: all_person,
        created_at: 3.days.ago,
        check_in_week_start: 3.days.ago.to_date.beginning_of_week(:monday)
      )
      create(:goal_association, goal: g_all, associable: create(:ability, company: company), created_at: 2.days.ago)
      g_all.update!(completed_at: 1.day.ago, started_at: 2.weeks.ago)

      g_conf = personal_goal!(owner: conf_tm)
      create(
        :goal_check_in,
        goal: g_conf,
        confidence_reporter: conf_person,
        created_at: 1.hour.ago,
        check_in_week_start: Date.current.beginning_of_week(:monday)
      )

      g_conn = personal_goal!(owner: conn_tm)
      create(:goal_association, goal: g_conn, associable: create(:assignment, company: company), created_at: 1.day.ago)

      names = described_class.new(company: company, range: nil).call.map(&:display_name)
      expect(names.first).to include("All")
      expect(names.second).to include("Conf")
      expect(names.third).to include("Conn")
    end

    it "respects the timeframe for confidence checks and completions" do
      goal = personal_goal!
      create(
        :goal_check_in,
        goal: goal,
        confidence_reporter: person,
        created_at: 10.days.ago,
        check_in_week_start: 10.days.ago.to_date.beginning_of_week(:monday)
      )
      old_goal = personal_goal!(attrs: { title: "Old", completed_at: 120.days.ago, started_at: 150.days.ago })

      rows = described_class.new(company: company, range: 90.days.ago..Time.current).call
      expect(rows.size).to eq(1)
      expect(rows.first.confidence_check_count).to eq(1)
      expect(rows.first.completion_count).to eq(0)
      expect(old_goal.completed_at).to be < 90.days.ago
    end
  end
end
