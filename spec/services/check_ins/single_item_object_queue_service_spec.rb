# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::SingleItemObjectQueueService do
  def eh_item(entity_type:, entity_id:, status:, inputs: {})
    instance_double(
      EngagementHealthStatus,
      entity_type: entity_type,
      entity_id: entity_id,
      status: status,
      inputs: inputs.stringify_keys
    )
  end

  let(:teammate) { build_stubbed(:company_teammate, id: 10, person_id: 100) }
  let(:employee) { build_stubbed(:person, id: 100) }
  let(:manager) { build_stubbed(:person, id: 200) }

  let(:items) do
    [
      { type: :assignment, id: 1, name: "Alpha", bucket: :red, my_side_completed_at: nil },
      { type: :assignment, id: 2, name: "Beta", bucket: :yellow, my_side_completed_at: 1.day.ago },
      { type: :assignment, id: 3, name: "Gamma", bucket: :yellow, my_side_completed_at: 1.day.ago },
      { type: :aspiration, id: 4, name: "Integrity", bucket: :green, my_side_completed_at: nil }
    ]
  end

  let(:eh_by_key) do
    {
      "assignment:1" => eh_item(
        entity_type: "Assignment",
        entity_id: 1,
        status: EngagementHealth::NEEDS_ATTENTION,
        inputs: {
          open_check_in_present: true,
          open_employee_completed: false,
          open_manager_completed: true
        }
      ),
      "assignment:2" => eh_item(
        entity_type: "Assignment",
        entity_id: 2,
        status: EngagementHealth::WARNING,
        inputs: {
          open_check_in_present: true,
          open_employee_completed: true,
          open_manager_completed: false
        }
      ),
      "assignment:3" => eh_item(
        entity_type: "Assignment",
        entity_id: 3,
        status: EngagementHealth::WARNING,
        inputs: {
          open_check_in_present: true,
          open_employee_completed: true,
          open_manager_completed: true,
          open_ready_for_finalization: true
        }
      ),
      "aspiration:4" => eh_item(
        entity_type: "Aspiration",
        entity_id: 4,
        status: EngagementHealth::HEALTHY,
        inputs: { open_check_in_present: false }
      )
    }
  end

  before do
    allow(EngagementHealth::UpNextSupport).to receive(:index_items_by_key).and_return(eh_by_key)
  end

  it "classifies the four viewer states for the employee (joint review is not your turn)" do
    result = described_class.call(
      items: items,
      engagement_health_records: [],
      teammate: teammate,
      current_person: employee,
      current_type: :assignment,
      current_id: 1
    )

    by_name = result[:rows].index_by { |row| row[:name] }
    expect(by_name["Alpha"][:viewer_state]).to eq(:your_turn)
    expect(by_name["Beta"][:viewer_state]).to eq(:waiting)
    expect(by_name["Gamma"][:viewer_state]).to eq(:review_together)
    expect(by_name["Integrity"][:viewer_state]).to eq(:clear)
    expect(result[:your_turn_count]).to eq(1)
    expect(result[:total_count]).to eq(4)
    expect(by_name["Alpha"][:current]).to eq(true)
  end

  it "keeps joint review muted for managers (not your turn)" do
    result = described_class.call(
      items: items,
      engagement_health_records: [],
      teammate: teammate,
      current_person: manager,
      current_type: :assignment,
      current_id: 2
    )

    by_name = result[:rows].index_by { |row| row[:name] }
    expect(by_name["Alpha"][:viewer_state]).to eq(:waiting) # manager already done
    expect(by_name["Beta"][:viewer_state]).to eq(:your_turn) # manager side open
    expect(by_name["Gamma"][:viewer_state]).to eq(:review_together)
    expect(result[:your_turn_count]).to eq(1)
  end

  it "orders your-turn items first" do
    result = described_class.call(
      items: items,
      engagement_health_records: [],
      teammate: teammate,
      current_person: employee,
      current_type: :assignment,
      current_id: 1
    )

    expect(result[:rows].first[:name]).to eq("Alpha")
  end
end
