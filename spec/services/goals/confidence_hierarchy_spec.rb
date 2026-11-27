# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::ConfidenceHierarchy do
  let(:organization) { create(:organization, :company) }
  let(:creator) { create(:company_teammate, organization: organization) }
  let(:person) { creator.person }
  let(:as_of) { Date.new(2026, 11, 25) }

  def make_goal(title:, parent: nil, parents: nil)
    goal = create(:goal, title: title, creator: creator, owner: creator, company: organization,
                         started_at: 8.weeks.ago)
    Array(parents || parent).compact.each do |p|
      create(:goal_link, parent: p, child: goal)
    end
    goal
  end

  def check!(goal, percentage:, weeks_ago:, reason: "reason")
    week = (as_of - weeks_ago.weeks).beginning_of_week(:monday)
    create(:goal_check_in, goal: goal, check_in_week_start: week,
                           confidence_percentage: percentage, confidence_reason: reason,
                           confidence_reporter: person)
  end

  describe "aggregates and agreement" do
    let!(:root) { make_goal(title: "H2 Intent") }
    let!(:parent_a) { make_goal(title: "50% of new deals choose PA", parent: root) }
    let!(:child_a) { make_goal(title: "Redesign demo", parent: parent_a) }
    let!(:parent_b) { make_goal(title: "PartnerHub+ sold to 4", parent: root) }
    let!(:child_b) { make_goal(title: "Child B", parent: parent_b) }
    let!(:silent) { make_goal(title: "Silent parent", parent: root) }
    let!(:silent_child) { make_goal(title: "Checked under silent", parent: silent) }
    let!(:leaf_no_kids) { make_goal(title: "Leaf alone", parent: root) }

    before do
      check!(parent_a, percentage: 50, weeks_ago: 18)
      check!(child_a, percentage: 80, weeks_ago: 18)
      check!(parent_b, percentage: 50, weeks_ago: 18)
      check!(child_b, percentage: 80, weeks_ago: 18)
      check!(silent_child, percentage: 60, weeks_ago: 2)
      check!(leaf_no_kids, percentage: 70, weeks_ago: 18)
      # two more at 50% for least-confident ties
      g1 = make_goal(title: "Floor 1", parent: root)
      g2 = make_goal(title: "Floor 2", parent: root)
      g3 = make_goal(title: "Floor 3", parent: root)
      g4 = make_goal(title: "Floor 4", parent: root)
      g5 = make_goal(title: "Floor 5", parent: root)
      [g1, g2, g3, g4, g5].each { |g| check!(g, percentage: 50, weeks_ago: 18) }
    end

    let(:goals) { Goal.where(company_id: organization.id).to_a }
    let(:service) { described_class.new(goals: goals, as_of: as_of) }
    let(:agg) { service.aggregates }

    it "counts goals below roots that carry a check" do
      expect(agg.goal_count_below_roots).to eq(goals.size - 1)
      expect(agg.checked_count).to eq(11)
    end

    it "reports least confident floor and tie count" do
      expect(agg.least_confident).to eq(50)
      expect(agg.least_confident_tie_count).to eq(7)
    end

    it "averages checked goals below roots" do
      # 7×50 + 2×80 + 60 + 70 = 350+160+60+70 = 640; 640/11 ≈ 58.18
      expect(agg.average_confidence).to be_within(0.1).of(640.0 / 11)
    end

    it "marks age buckets for checked goals" do
      expect(agg.age_buckets).to eq(fresh: 0, aging: 1, stale: 10, never: 0)
    end

    it "flags should_be_higher for parents at 50% over an 80% child" do
      expect(service.agreement(parent_a).state).to eq(:should_be_higher)
      expect(service.agreement(parent_b).state).to eq(:should_be_higher)
    end

    it "flags no_check when parent is silent and children are not" do
      expect(service.agreement(silent).state).to eq(:no_check)
    end

    it "flags none when nothing beneath carries a check" do
      expect(service.agreement(leaf_no_kids).state).to eq(:none)
    end
  end

  describe "primary parent and multi-parent" do
    let!(:root_a) { make_goal(title: "Parent A") }
    let!(:root_b) { make_goal(title: "Parent B") }
    let!(:shared) { make_goal(title: "Shared", parents: [root_b, root_a]) }
    let!(:under_shared) { make_goal(title: "Under shared", parent: shared) }

    let(:service) do
      described_class.new(goals: [root_a, root_b, shared, under_shared], as_of: as_of)
    end

    it "uses the lowest parent id as primary" do
      primary = [root_a, root_b].min_by(&:id)
      expect(service.primary_parent(shared)).to eq(primary)
    end

    it "renders the shared subtree only under the primary parent" do
      rows = service.tree_rows
      shared_rows = rows.select { |r| r.goal.id == shared.id }
      expect(shared_rows.size).to eq(1)
      expect(shared_rows.first.depth).to eq(1)
      expect(rows.count { |r| r.goal.id == under_shared.id }).to eq(1)
    end
  end

  describe "first/latest and arrows" do
    let!(:root) { make_goal(title: "Root") }
    let!(:goal) { make_goal(title: "Tracked", parent: root) }

    before do
      check!(goal, percentage: 55, weeks_ago: 10, reason: "first")
      check!(goal, percentage: 50, weeks_ago: 2, reason: "latest")
    end

    let(:service) { described_class.new(goals: [root, goal], as_of: as_of) }

    it "exposes first and latest check-ins" do
      expect(service.first_check_in(goal).confidence_percentage).to eq(55)
      expect(service.latest_check_in(goal).confidence_percentage).to eq(50)
      expect(service.arrow(goal)).to eq(:down)
      expect(service.confidence_delta(goal)).to eq(-5)
    end

    it "includes biggest drop in aggregates" do
      expect(service.aggregates.biggest_drop).to eq(-5)
    end
  end

  describe "empty spotlight" do
    let!(:root) { make_goal(title: "Empty root") }
    let!(:child) { make_goal(title: "Draft child", parent: root) }
    let(:agg) { described_class.new(goals: [root, child], as_of: as_of).aggregates }

    it "is empty when no checks exist below roots" do
      expect(agg.empty).to be true
      expect(agg.checked_count).to eq(0)
      expect(agg.goal_count_below_roots).to eq(1)
    end
  end
end
