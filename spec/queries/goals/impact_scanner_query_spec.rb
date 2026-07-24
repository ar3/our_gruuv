# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::ImpactScannerQuery do
  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: company) }
  let(:person) { teammate.person }

  def create_public_goal!(title:, initial_confidence: "stretch")
    create(
      :goal,
      :everyone_in_company,
      :active,
      creator: teammate,
      owner: teammate,
      company: company,
      title: title,
      initial_confidence: initial_confidence,
      most_likely_target_date: Date.today + 30.days,
      started_at: Time.current
    )
  end

  def create_check_in!(goal, percentage)
    create(
      :goal_check_in,
      goal: goal,
      confidence_percentage: percentage,
      confidence_reporter: person,
      check_in_week_start: Date.current.beginning_of_week(:monday)
    )
  end

  describe ".latest_confidence_band_for" do
    it "maps latest percentages to high / mid / low bands (not commit/stretch/transform)" do
      expect(described_class.latest_confidence_band_for(nil)).to eq(:no_check_in)
      expect(described_class.latest_confidence_band_for(80)).to eq(:high)
      expect(described_class.latest_confidence_band_for(79)).to eq(:mid)
      expect(described_class.latest_confidence_band_for(50)).to eq(:mid)
      expect(described_class.latest_confidence_band_for(49)).to eq(:low)
    end
  end

  describe "#call" do
    let!(:parent) { create_public_goal!(title: "Parent", initial_confidence: "commit") }
    let!(:child_a) { create_public_goal!(title: "Child A") }
    let!(:child_b) { create_public_goal!(title: "Child B") }
    let!(:grandchild) { create_public_goal!(title: "Grandchild") }

    before do
      create(:goal_link, parent: parent, child: child_a)
      create(:goal_link, parent: parent, child: child_b)
      create(:goal_link, parent: child_b, child: grandchild)
      create_check_in!(child_a, 85)
      create_check_in!(child_b, 55)
      create_check_in!(grandchild, 20)
    end

    it "rolls up the full descendant tree into an advisory latest-confidence distribution" do
      result = described_class.new(
        goals: [parent, child_a, child_b, grandchild],
        current_person: person,
        organization: company
      ).call

      root = result[:root_goals].first
      expect(root[:goal]).to eq(parent)

      rollup = root[:confidence_rollup]
      expect(rollup.descendant_count).to eq(3)
      expect(rollup.bands.high).to eq(1)
      expect(rollup.bands.mid).to eq(1)
      expect(rollup.bands.low).to eq(1)
      expect(rollup.bands.no_check_in).to eq(0)
      expect(rollup.average_confidence).to eq(53.3)
      expect(rollup.checked_in_count).to eq(3)
    end

    it "counts missing check-ins in the no_check_in band" do
      orphan = create_public_goal!(title: "No check-in child")
      create(:goal_link, parent: parent, child: orphan)

      result = described_class.new(
        goals: [parent, child_a, child_b, grandchild, orphan],
        current_person: person,
        organization: company
      ).call

      rollup = result[:root_goals].first[:confidence_rollup]
      expect(rollup.bands.no_check_in).to eq(1)
      expect(rollup.descendant_count).to eq(4)
      expect(rollup.checked_in_count).to eq(3)
    end
  end
end
