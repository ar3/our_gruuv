# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::SingleItemCheckInNextItemService do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let(:current_person) { teammate.person }
  let(:healthy_days) { EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS }
  let(:needs_attention_days) { EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS }

  describe ".call" do
    it "returns a hash with next_url, next_requires_check_in, next_item, ordered_items" do
      result = described_class.call(
        teammate: teammate,
        organization: organization,
        current_person: current_person,
        current_type: :position,
        current_id: nil
      )
      expect(result).to include(:next_url, :next_requires_check_in, :next_item, :ordered_items, :show_check_in_status_done)
      expect(result[:ordered_items]).to be_an(Array)
    end

    context "with no employment" do
      it "still returns structure with empty or position-only items" do
        result = described_class.call(
          teammate: teammate,
          organization: organization,
          current_person: current_person,
          current_type: :aspiration,
          current_id: 0
        )
        expect(result[:next_requires_check_in]).to be_in([true, false])
      end
    end
  end

  describe "next item resolution (resolve_next_item)" do
    let(:service) do
      described_class.new(
        teammate: teammate,
        organization: organization,
        current_person: current_person,
        current_type: :assignment,
        current_id: green_assignment_id
      )
    end
    let(:green_assignment_id) { 200 }
    let(:yellow_assignment_id) { 100 }
    let(:fixture_items) do
      [
        { type: :assignment, id: yellow_assignment_id, name: "Yellow", bucket: described_class::BUCKET_YELLOW },
        { type: :assignment, id: green_assignment_id, name: "Current", bucket: described_class::BUCKET_GREEN },
        { type: :position, id: nil, name: "Position", bucket: described_class::BUCKET_GREEN }
      ]
    end

    it "prefers a more urgent bucket over circular next in the green section" do
      next_pick = service.send(:resolve_next_item, fixture_items, 1)
      expect(next_pick[:id]).to eq(yellow_assignment_id)
    end

    it "uses circular order when no other item is more urgent" do
      only_green = [
        { type: :assignment, id: 1, name: "First", bucket: described_class::BUCKET_GREEN },
        { type: :assignment, id: 2, name: "Second", bucket: described_class::BUCKET_GREEN }
      ]
      s2 = described_class.new(
        teammate: teammate,
        organization: organization,
        current_person: current_person,
        current_type: :assignment,
        current_id: 1
      )
      expect(s2.send(:resolve_next_item, only_green, 0)[:id]).to eq(2)
    end
  end

  describe "EH Healthy bucket from latest finalized" do
    it "uses Healthy (green) when open side is incomplete but item was finalized within the EH window" do
      aspiration = create(:aspiration, company: organization, name: "Be Kind")
      create(
        :aspiration_check_in,
        teammate: teammate,
        aspiration: aspiration,
        employee_completed_at: nil,
        manager_completed_at: nil,
        official_check_in_completed_at: nil
      )
      create(
        :aspiration_check_in,
        :finalized,
        teammate: teammate,
        aspiration: aspiration,
        official_check_in_completed_at: (healthy_days - 5).days.ago
      )

      result = described_class.call(
        teammate: teammate,
        organization: organization,
        current_person: current_person,
        current_type: :aspiration,
        current_id: aspiration.id
      )

      item = result[:ordered_items].find { |i| i[:name] == "Be Kind" }
      expect(item[:my_side_completed_at]).to be_nil
      expect(item[:bucket]).to eq(described_class::BUCKET_GREEN)
    end

    it "treats finalized within Healthy window as green even past the old 30-day crystal-clear window" do
      aspiration = create(:aspiration, company: organization, name: "Still Healthy")
      create(
        :aspiration_check_in,
        :finalized,
        teammate: teammate,
        aspiration: aspiration,
        official_check_in_completed_at: (CheckInBehavior::CLARITY_CRYSTAL_CLEAR_DAYS + 10).days.ago
      )

      result = described_class.call(
        teammate: teammate,
        organization: organization,
        current_person: current_person,
        current_type: :aspiration,
        current_id: aspiration.id
      )

      item = result[:ordered_items].find { |i| i[:name] == "Still Healthy" }
      expect(item[:bucket]).to eq(described_class::BUCKET_GREEN)
      expect(result[:next_requires_check_in]).to be(false)
    end

    it "uses Warning (yellow) between Healthy and Needs Attention windows" do
      aspiration = create(:aspiration, company: organization, name: "Getting Stale")
      create(
        :aspiration_check_in,
        :finalized,
        teammate: teammate,
        aspiration: aspiration,
        official_check_in_completed_at: (healthy_days + 5).days.ago
      )

      result = described_class.call(
        teammate: teammate,
        organization: organization,
        current_person: current_person,
        current_type: :aspiration,
        current_id: aspiration.id
      )

      item = result[:ordered_items].find { |i| i[:name] == "Getting Stale" }
      expect(item[:bucket]).to eq(described_class::BUCKET_YELLOW)
      expect(result[:next_requires_check_in]).to be(true)
    end

    it "does not treat recent open-side completion as Healthy when never finalized" do
      aspiration = create(:aspiration, company: organization, name: "Never Done")
      create(
        :aspiration_check_in,
        teammate: teammate,
        aspiration: aspiration,
        employee_completed_at: 1.day.ago,
        manager_completed_at: nil,
        official_check_in_completed_at: nil
      )

      result = described_class.call(
        teammate: teammate,
        organization: organization,
        current_person: current_person,
        current_type: :aspiration,
        current_id: aspiration.id
      )

      item = result[:ordered_items].find { |i| i[:name] == "Never Done" }
      expect(item[:bucket]).to eq(described_class::BUCKET_RED)
      expect(result[:next_requires_check_in]).to be(true)
    end
  end

  describe "ordering among incomplete open sides" do
    it "ranks a more urgent EH bucket before a recently finalized Healthy item with the same incomplete open side" do
      be_kind = create(:aspiration, company: organization, name: "Be Kind")
      keep_growing = create(:aspiration, company: organization, name: "Keep Growing")

      create(:aspiration_check_in, teammate: teammate, aspiration: be_kind, employee_completed_at: nil, official_check_in_completed_at: nil)
      create(:aspiration_check_in, :finalized, teammate: teammate, aspiration: be_kind, official_check_in_completed_at: 6.days.ago)

      create(:aspiration_check_in, teammate: teammate, aspiration: keep_growing, employee_completed_at: nil, official_check_in_completed_at: nil)
      create(
        :aspiration_check_in,
        :finalized,
        teammate: teammate,
        aspiration: keep_growing,
        official_check_in_completed_at: (healthy_days + 5).days.ago
      )

      result = described_class.call(
        teammate: teammate,
        organization: organization,
        current_person: current_person,
        current_type: :position,
        current_id: nil
      )

      aspiration_names = result[:ordered_items].select { |i| i[:type] == :aspiration }.map { |i| i[:name] }
      expect(aspiration_names.first).to eq("Keep Growing")
      expect(aspiration_names.second).to eq("Be Kind")
    end

    it "ranks type before oldest clarity activity within the same bucket" do
      aspiration = create(:aspiration, company: organization, name: "Older Value")
      assignment = create(:assignment, company: organization, title: "Newer Assignment")
      create(:assignment_tenure, teammate: teammate, assignment: assignment, started_at: 6.months.ago, ended_at: nil)

      old_activity = (healthy_days + 5).days.ago
      new_activity = (healthy_days + 10).days.ago

      create(:aspiration_check_in, teammate: teammate, aspiration: aspiration, employee_completed_at: nil, official_check_in_completed_at: nil)
      create(:aspiration_check_in, :finalized, teammate: teammate, aspiration: aspiration, official_check_in_completed_at: old_activity)

      create(:assignment_check_in, teammate: teammate, assignment: assignment, employee_completed_at: nil, official_check_in_completed_at: nil)
      create(:assignment_check_in, :finalized, teammate: teammate, assignment: assignment, official_check_in_completed_at: new_activity)

      result = described_class.call(
        teammate: teammate,
        organization: organization,
        current_person: current_person,
        current_type: :position,
        current_id: nil
      )

      names = result[:ordered_items].first(2).map { |i| i[:name] }
      expect(names).to eq(["Older Value", "Newer Assignment"])
    end
  end

  describe "ordering by viewing side completion timing" do
    it "orders nil my-side completion first, then oldest to newest, then type and name" do
      position_major_level = create(:position_major_level)
      title = create(:title, company: organization, position_major_level: position_major_level)
      position_level = create(:position_level, position_major_level: position_major_level)
      position = create(:position, title: title, position_level: position_level)
      teammate.employment_tenures.update_all(ended_at: Time.current)
      create(:employment_tenure, teammate: teammate, company: organization, position: position, started_at: 1.year.ago, ended_at: nil)

      alpha_aspiration = create(:aspiration, company: organization, name: "Alpha Aspiration")
      zeta_aspiration = create(:aspiration, company: organization, name: "Zeta Aspiration")
      older_assignment = create(:assignment, company: organization, title: "Older Assignment")
      newer_assignment = create(:assignment, company: organization, title: "Newer Assignment")
      create(:assignment_tenure, teammate: teammate, assignment: older_assignment, started_at: 7.months.ago, ended_at: nil)
      create(:assignment_tenure, teammate: teammate, assignment: newer_assignment, started_at: 6.months.ago, ended_at: nil)

      create(:aspiration_check_in, teammate: teammate, aspiration: alpha_aspiration, employee_completed_at: nil, official_check_in_completed_at: nil)
      create(:aspiration_check_in, teammate: teammate, aspiration: zeta_aspiration, employee_completed_at: nil, official_check_in_completed_at: nil)
      create(:assignment_check_in, teammate: teammate, assignment: older_assignment, employee_completed_at: 40.days.ago, official_check_in_completed_at: nil)
      create(:assignment_check_in, teammate: teammate, assignment: newer_assignment, employee_completed_at: 10.days.ago, official_check_in_completed_at: nil)
      PositionCheckIn.find_or_create_open_for(teammate).update!(employee_completed_at: 5.days.ago)

      result = described_class.call(
        teammate: teammate,
        organization: organization,
        current_person: current_person,
        current_type: :position,
        current_id: nil
      )

      ordered_items = result[:ordered_items]
      expect(ordered_items.map { |i| i[:name] }).to eq([
        "Alpha Aspiration",
        "Zeta Aspiration",
        "Older Assignment",
        "Newer Assignment",
        position.title.external_title
      ])
    end
  end
end
