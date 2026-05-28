# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::SingleItemCheckInNextItemService do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let(:current_person) { teammate.person }

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

  describe "ordering required check-ins first" do
    it "puts required and active-tenure assignments ahead of non-required items" do
      position_major_level = create(:position_major_level)
      title = create(:title, company: organization, position_major_level: position_major_level)
      position_level = create(:position_level, position_major_level: position_major_level)
      position = create(:position, title: title, position_level: position_level)
      teammate.employment_tenures.update_all(ended_at: Time.current)
      create(:employment_tenure, teammate: teammate, company: organization, position: position, started_at: 1.year.ago, ended_at: nil)

      required_assignment = create(:assignment, company: organization, title: "Required Assignment")
      active_assignment = create(:assignment, company: organization, title: "Active Tenure Assignment")
      optional_aspiration = create(:aspiration, company: organization, name: "Optional Aspiration")
      create(:position_assignment, position: position, assignment: required_assignment, assignment_type: "required")
      create(:assignment_tenure, teammate: teammate, assignment: active_assignment, started_at: 6.months.ago, ended_at: nil)

      create(:assignment_check_in, teammate: teammate, assignment: active_assignment, employee_completed_at: 10.days.ago)
      create(:aspiration_check_in, teammate: teammate, aspiration: optional_aspiration, employee_completed_at: 120.days.ago)
      allow_any_instance_of(described_class).to receive(:required_position_assignment_ids).and_return([required_assignment.id])

      result = described_class.call(
        teammate: teammate,
        organization: organization,
        current_person: current_person,
        current_type: :position,
        current_id: nil
      )

      ordered_items = result[:ordered_items]
      first_non_required_index = ordered_items.index { |i| !i[:required] }

      expect(ordered_items.any? { |i| i[:name] == "Required Assignment" && i[:required] }).to be(true)
      expect(ordered_items.any? { |i| i[:name] == "Active Tenure Assignment" && i[:required] }).to be(true)
      expect(first_non_required_index).not_to be_nil
      expect(ordered_items.first(first_non_required_index).all? { |i| i[:required] }).to be(true)
    end
  end
end
