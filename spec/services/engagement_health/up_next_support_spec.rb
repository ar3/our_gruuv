# frozen_string_literal: true

require "rails_helper"

RSpec.describe EngagementHealth::UpNextSupport do
  def eh_item(status:, inputs: {})
    instance_double(
      EngagementHealthStatus,
      status: status,
      inputs: inputs.stringify_keys
    )
  end

  describe ".actions_needed_count" do
    it "returns 0 for healthy items" do
      item = eh_item(status: EngagementHealth::HEALTHY, inputs: { "open_check_in_present" => true })

      expect(described_class.actions_needed_count(item, manager_perspective: false)).to eq(0)
    end

    it "returns 1 when warning and no open check-in" do
      item = eh_item(status: EngagementHealth::WARNING, inputs: { "open_check_in_present" => false })

      expect(described_class.actions_needed_count(item, manager_perspective: false)).to eq(1)
    end

    it "counts incomplete employee side on an open check-in" do
      item = eh_item(
        status: EngagementHealth::NEEDS_ATTENTION,
        inputs: {
          "open_check_in_present" => true,
          "open_employee_completed" => false,
          "open_manager_completed" => true
        }
      )

      expect(described_class.actions_needed_count(item, manager_perspective: false)).to eq(1)
      expect(described_class.actions_needed_count(item, manager_perspective: true)).to eq(0)
    end

    it "counts finalize for manager when ready for finalization" do
      item = eh_item(
        status: EngagementHealth::WARNING,
        inputs: {
          "open_check_in_present" => true,
          "open_employee_completed" => true,
          "open_manager_completed" => true,
          "open_ready_for_finalization" => true
        }
      )

      expect(described_class.actions_needed_count(item, manager_perspective: true)).to eq(1)
    end
  end

  describe ".sort_items_for_perspective" do
    let(:eh_by_key) do
      {
        "aspiration:1" => eh_item(status: EngagementHealth::HEALTHY),
        "assignment:2" => eh_item(
          status: EngagementHealth::NEEDS_ATTENTION,
          inputs: { "open_check_in_present" => true, "open_employee_completed" => false }
        )
      }
    end

    it "orders items needing action before healthy items" do
      items = [
        { type: :aspiration, id: 1, name: "A" },
        { type: :assignment, id: 2, name: "B" }
      ]

      sorted = described_class.sort_items_for_perspective(
        items,
        eh_by_key: eh_by_key,
        manager_perspective: false
      )

      expect(sorted.map { |i| i[:name] }).to eq(%w[B A])
    end
  end

  describe ".item_key" do
    it "aligns position items between up next and engagement health" do
      eh_status = instance_double(EngagementHealthStatus, entity_type: "Position", entity_id: 42)
      up_next_item = { type: :position, id: 42 }

      expect(described_class.item_key(eh_status)).to eq("position:42")
      expect(described_class.item_key(up_next_item)).to eq("position:42")
    end
  end

  describe ".find_item" do
    it "finds position engagement health by id or legacy none key" do
      position_item = instance_double(EngagementHealthStatus, entity_type: "Position", entity_id: 42, status: EngagementHealth::HEALTHY, inputs: {})
      eh_by_key = { "position:42" => position_item, "position:none" => position_item }

      expect(described_class.find_item(eh_by_key, { type: :position, id: 42 })).to eq(position_item)
      expect(described_class.find_item({ "position:none" => position_item }, { type: :position, id: nil })).to eq(position_item)
    end
  end

  describe ".workflow_completion" do
    it "reads completion from the open check-in when present" do
      open_check_in = instance_double(
        "CheckIn",
        employee_completed_at: Time.current,
        manager_completed_at: nil,
        ready_for_finalization?: false
      )

      result = described_class.workflow_completion(eh_item: nil, latest_open: open_check_in)

      expect(result).to eq(
        employee_done: true,
        manager_done: false,
        ready_for_joint_review: false
      )
    end

    it "falls back to engagement health inputs when there is no open check-in" do
      item = eh_item(
        status: EngagementHealth::NEEDS_ATTENTION,
        inputs: {
          "open_employee_completed" => true,
          "open_manager_completed" => true,
          "open_ready_for_finalization" => true
        }
      )

      result = described_class.workflow_completion(eh_item: item, latest_open: nil)

      expect(result).to eq(
        employee_done: true,
        manager_done: true,
        ready_for_joint_review: true
      )
    end
  end

  describe ".actions_total_count" do
    it "counts healthy items toward the total" do
      item = eh_item(status: EngagementHealth::HEALTHY)

      expect(described_class.actions_total_count(item, manager_perspective: false)).to eq(1)
      expect(described_class.actions_total_count(item, manager_perspective: true)).to eq(2)
    end
  end

  describe ".actions_line" do
    it "describes required actions for needs attention" do
      item = eh_item(status: EngagementHealth::NEEDS_ATTENTION)

      expect(described_class.actions_line(count: 1, person_name: "Nesha", eh_item: item)).to eq(
        "1 action required from Nesha"
      )
    end

    it "describes encouraged actions for warning" do
      item = eh_item(status: EngagementHealth::WARNING)

      expect(described_class.actions_line(count: 1, person_name: "Tulay", eh_item: item)).to eq(
        "1 action encouraged from Tulay"
      )
    end
  end
end
