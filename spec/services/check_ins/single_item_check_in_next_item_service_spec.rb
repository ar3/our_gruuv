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

  describe "next item resolution (your-turn first, then bucket)" do
    def service_for(current_type:, current_id:)
      described_class.new(
        teammate: teammate,
        organization: organization,
        current_person: current_person,
        current_type: current_type,
        current_id: current_id
      )
    end

    it "excludes current and picks the first remaining your-turn item (worst bucket among incomplete my-side)" do
      items = [
        { type: :assignment, id: 1, name: "Yellow", bucket: described_class::BUCKET_YELLOW, my_side_completed_at: nil },
        { type: :assignment, id: 2, name: "Current Green", bucket: described_class::BUCKET_GREEN, my_side_completed_at: nil },
        { type: :assignment, id: 3, name: "Other Green", bucket: described_class::BUCKET_GREEN, my_side_completed_at: nil }
      ]
      next_pick = service_for(current_type: :assignment, current_id: 2).send(:resolve_next_item, items, 1)
      expect(next_pick[:id]).to eq(1)
    end

    it "prefers any your-turn incomplete item over a worse-bucket item that already has my-side done" do
      # Sorted as the service would: nil my-side first (yellow, then green), then red with my-side done
      items = [
        { type: :assignment, id: 10, name: "Yellow your turn", bucket: described_class::BUCKET_YELLOW, my_side_completed_at: nil },
        { type: :assignment, id: 20, name: "Green your turn", bucket: described_class::BUCKET_GREEN, my_side_completed_at: nil },
        { type: :assignment, id: 30, name: "Red my-side done", bucket: described_class::BUCKET_RED, my_side_completed_at: 2.days.ago }
      ]
      next_pick = service_for(current_type: :assignment, current_id: 10).send(:resolve_next_item, items, 0)
      expect(next_pick[:id]).to eq(20)
    end

    it "among same-urgency your-turn items, does not skip earlier items via circular walk" do
      items = [
        { type: :assignment, id: 1, name: "Red A", bucket: described_class::BUCKET_RED, my_side_completed_at: nil },
        { type: :assignment, id: 2, name: "Red B current", bucket: described_class::BUCKET_RED, my_side_completed_at: nil },
        { type: :assignment, id: 3, name: "Red C", bucket: described_class::BUCKET_RED, my_side_completed_at: nil }
      ]
      next_pick = service_for(current_type: :assignment, current_id: 2).send(:resolve_next_item, items, 1)
      expect(next_pick[:id]).to eq(1)
    end

    it "falls back to first remaining my-side-done item when no your-turn items remain" do
      items = [
        { type: :assignment, id: 1, name: "Current", bucket: described_class::BUCKET_GREEN, my_side_completed_at: nil },
        { type: :assignment, id: 2, name: "Older done", bucket: described_class::BUCKET_YELLOW, my_side_completed_at: 40.days.ago },
        { type: :assignment, id: 3, name: "Newer done", bucket: described_class::BUCKET_YELLOW, my_side_completed_at: 5.days.ago }
      ]
      next_pick = service_for(current_type: :assignment, current_id: 1).send(:resolve_next_item, items, 0)
      expect(next_pick[:id]).to eq(2)
    end
  end

  describe "end-to-end next_item scenarios" do
    def call_for(current_type:, current_id:)
      described_class.call(
        teammate: teammate,
        organization: organization,
        current_person: current_person,
        current_type: current_type,
        current_id: current_id
      )
    end

    it "from a your-turn yellow, moves to your-turn green rather than red with my-side already done" do
      yellow = create(:aspiration, company: organization, name: "Yellow Open")
      green = create(:aspiration, company: organization, name: "Green Open")
      red_done = create(:aspiration, company: organization, name: "Red Done")

      create(:aspiration_check_in, teammate: teammate, aspiration: yellow, employee_completed_at: nil, official_check_in_completed_at: nil)
      create(
        :aspiration_check_in,
        :finalized,
        teammate: teammate,
        aspiration: yellow,
        official_check_in_completed_at: (healthy_days + 5).days.ago
      )

      create(:aspiration_check_in, teammate: teammate, aspiration: green, employee_completed_at: nil, official_check_in_completed_at: nil)
      create(
        :aspiration_check_in,
        :finalized,
        teammate: teammate,
        aspiration: green,
        official_check_in_completed_at: (healthy_days - 5).days.ago
      )

      create(
        :aspiration_check_in,
        teammate: teammate,
        aspiration: red_done,
        employee_completed_at: 3.days.ago,
        official_check_in_completed_at: nil
      )

      result = call_for(current_type: :aspiration, current_id: yellow.id)

      expect(result[:next_item][:name]).to eq("Green Open")
      expect(result[:next_item][:my_side_completed_at]).to be_nil
    end

    it "among your-turn items, picks the worst EH bucket after excluding current" do
      red = create(:aspiration, company: organization, name: "Needs Attention")
      yellow = create(:aspiration, company: organization, name: "Warning")
      green = create(:aspiration, company: organization, name: "Healthy")

      create(:aspiration_check_in, teammate: teammate, aspiration: red, employee_completed_at: nil, official_check_in_completed_at: nil)
      create(:aspiration_check_in, teammate: teammate, aspiration: yellow, employee_completed_at: nil, official_check_in_completed_at: nil)
      create(
        :aspiration_check_in,
        :finalized,
        teammate: teammate,
        aspiration: yellow,
        official_check_in_completed_at: (healthy_days + 5).days.ago
      )
      create(:aspiration_check_in, teammate: teammate, aspiration: green, employee_completed_at: nil, official_check_in_completed_at: nil)
      create(
        :aspiration_check_in,
        :finalized,
        teammate: teammate,
        aspiration: green,
        official_check_in_completed_at: (healthy_days - 5).days.ago
      )

      result = call_for(current_type: :aspiration, current_id: yellow.id)

      expect(result[:next_item][:name]).to eq("Needs Attention")
    end

    it "when every other item has my-side done, picks the worst-bucket remaining item" do
      current = create(:aspiration, company: organization, name: "Current Open")
      yellow_done = create(:aspiration, company: organization, name: "Yellow Done")
      red_done = create(:aspiration, company: organization, name: "Red Done")

      create(:aspiration_check_in, teammate: teammate, aspiration: current, employee_completed_at: nil, official_check_in_completed_at: nil)
      create(
        :aspiration_check_in,
        :finalized,
        teammate: teammate,
        aspiration: current,
        official_check_in_completed_at: (healthy_days - 5).days.ago
      )

      create(
        :aspiration_check_in,
        teammate: teammate,
        aspiration: yellow_done,
        employee_completed_at: 2.days.ago,
        official_check_in_completed_at: nil
      )
      create(
        :aspiration_check_in,
        :finalized,
        teammate: teammate,
        aspiration: yellow_done,
        official_check_in_completed_at: (healthy_days + 5).days.ago
      )

      create(
        :aspiration_check_in,
        teammate: teammate,
        aspiration: red_done,
        employee_completed_at: 1.day.ago,
        official_check_in_completed_at: nil
      )

      result = call_for(current_type: :aspiration, current_id: current.id)

      expect(result[:next_item][:name]).to eq("Red Done")
    end

    it "uses manager_completed_at for my-side when the viewer is not the teammate" do
      manager = create(:person)
      manager_ct = create(:company_teammate, organization: organization, person: manager)

      open_for_employee = create(:aspiration, company: organization, name: "Employee Still Open")
      open_for_manager = create(:aspiration, company: organization, name: "Manager Still Open")

      create(
        :aspiration_check_in,
        teammate: teammate,
        aspiration: open_for_employee,
        employee_completed_at: nil,
        manager_completed_at: 1.day.ago,
        manager_completed_by_teammate: manager_ct,
        official_check_in_completed_at: nil
      )
      create(
        :aspiration_check_in,
        teammate: teammate,
        aspiration: open_for_manager,
        employee_completed_at: 1.day.ago,
        manager_completed_at: nil,
        official_check_in_completed_at: nil
      )

      result = described_class.call(
        teammate: teammate,
        organization: organization,
        current_person: manager,
        current_type: :aspiration,
        current_id: open_for_employee.id
      )

      expect(result[:next_item][:name]).to eq("Manager Still Open")
      expect(result[:next_item][:my_side_completed_at]).to be_nil
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
    it "orders nil my-side first, then my-side-done by bucket then oldest completion, then type and name" do
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

    it "among my-side-done items, ranks worse EH bucket before older my-side completion" do
      red_newer = create(:aspiration, company: organization, name: "Red Newer Done")
      yellow_older = create(:aspiration, company: organization, name: "Yellow Older Done")

      create(
        :aspiration_check_in,
        teammate: teammate,
        aspiration: red_newer,
        employee_completed_at: 2.days.ago,
        official_check_in_completed_at: nil
      )
      create(
        :aspiration_check_in,
        teammate: teammate,
        aspiration: yellow_older,
        employee_completed_at: 40.days.ago,
        official_check_in_completed_at: nil
      )
      create(
        :aspiration_check_in,
        :finalized,
        teammate: teammate,
        aspiration: yellow_older,
        official_check_in_completed_at: (healthy_days + 5).days.ago
      )

      result = described_class.call(
        teammate: teammate,
        organization: organization,
        current_person: current_person,
        current_type: :position,
        current_id: nil
      )

      done_names = result[:ordered_items]
        .select { |i| i[:type] == :aspiration && i[:my_side_completed_at].present? }
        .map { |i| i[:name] }
      expect(done_names).to eq(["Red Newer Done", "Yellow Older Done"])
    end
  end
end
