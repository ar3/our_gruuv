require "rails_helper"

RSpec.describe OneOnOne::PriorityCarouselBuilder, type: :service do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }

  describe ".call" do
    it "builds 12 ordered priorities and starts at first attention item" do
      one_on_one_link = create(:one_on_one_link, teammate: teammate, url: "https://app.asana.com/0/123/456")

      result = described_class.call(
        organization: organization,
        teammate: teammate,
        one_on_one_link: one_on_one_link
      )

      expect(result[:priorities].size).to eq(12)
      expect(result[:priorities].first[:title]).to eq(described_class::ASANA_URGENT_TASKS_TITLE)
      expect(result[:priorities].first[:needs_attention]).to eq(true)
      expect(result[:first_attention_index]).to eq(0)
    end

    it "marks Asana-specific priorities as not applicable when no Asana source" do
      one_on_one_link = create(:one_on_one_link, teammate: teammate, url: "https://example.com/1-1")

      result = described_class.call(
        organization: organization,
        teammate: teammate,
        one_on_one_link: one_on_one_link
      )

      first = result[:priorities][0]
      eighth = result[:priorities][8]
      tenth = result[:priorities][9]

      expect(first[:title]).to eq(described_class::ASANA_URGENT_TASKS_TITLE)
      expect(first[:not_applicable]).to eq(true)
      expect(first[:needs_attention]).to eq(false)
      expect(eighth[:title]).to eq("Does #{teammate.person.casual_name} have at least one active goal?")
      expect(tenth[:title]).to eq(described_class::REMAINING_ASANA_TASKS_TITLE)
      expect(tenth[:not_applicable]).to eq(true)
    end

    it "includes Asana task permalinks in urgent-task concrete items when tasks have gids" do
      due = Date.current.strftime("%Y-%m-%d")
      one_on_one_link = create(
        :one_on_one_link,
        teammate: teammate,
        url: "https://app.asana.com/0/999888/777",
        deep_integration_config: { "asana_project_id" => "999888" }
      )
      create(
        :external_project_cache,
        cacheable: one_on_one_link,
        items_data: [
          {
            "gid" => "task-abc",
            "name" => "Ship feature",
            "completed" => false,
            "due_on" => due
          }
        ]
      )

      result = described_class.call(
        organization: organization,
        teammate: teammate,
        one_on_one_link: one_on_one_link
      )

      urgent = result[:priorities].find { |p| p[:title] == described_class::ASANA_URGENT_TASKS_TITLE }
      expect(urgent[:needs_attention]).to eq(true)
      item = urgent[:concrete_items].first
      expect(item).to be_a(Hash)
      expect(item[:url]).to eq("https://app.asana.com/0/999888/task-abc")
      expect(item[:label]).to include("Ship feature")
    end
  end
end
