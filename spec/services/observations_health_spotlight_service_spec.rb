# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObservationsHealthSpotlightService do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
  end

  subject(:service) do
    described_class.new(
      organization: organization,
      current_person: person,
      current_company_teammate: teammate,
      manage_employment: true
    )
  end

  def create_ogo_statuses(given_status:, received_status:, last_given_at: 1.day.ago, last_received_at: 1.day.ago)
    EngagementHealthStatus.create!(
      teammate: teammate,
      organization: organization,
      level: "category",
      category: EngagementHealth::CATEGORY_OGO_GIVEN,
      status: given_status,
      inputs: { "last_event_at" => last_given_at&.iso8601, "never" => last_given_at.nil? },
      computed_at: Time.current
    )
    EngagementHealthStatus.create!(
      teammate: teammate,
      organization: organization,
      level: "category",
      category: EngagementHealth::CATEGORY_OGO_RECEIVED,
      status: received_status,
      inputs: { "last_event_at" => last_received_at&.iso8601, "never" => last_received_at.nil? },
      computed_at: Time.current
    )
  end

  describe "#rows_and_spotlight_for" do
    it "builds Given/Received from EngagementHealth and maps overall Healthy to healthy spotlight status" do
      create_ogo_statuses(
        given_status: EngagementHealth::HEALTHY,
        received_status: EngagementHealth::HEALTHY
      )
      create(
        :observation_health_cache,
        teammate: teammate,
        organization: organization,
        payload: {
          "given" => { "status" => "green", "observations_count" => 4 },
          "received" => { "status" => "green", "observations_count" => 2 },
          "kudos_mix" => { "band" => "healthy", "kudos_count" => 3, "constructive_count" => 1, "display_ratio" => "3:1" },
          "rating_intensity" => { "band" => "healthy", "less_extreme_count" => 6, "most_extreme_count" => 2, "display_ratio" => "3:1" },
          "overall_status" => "green"
        }
      )

      data = service.rows_and_spotlight_for("just_me")
      row = data[:rows].find { |r| r[:teammate].id == teammate.id }

      expect(row[:status]).to eq(:healthy)
      expect(row[:given]["status"]).to eq(EngagementHealth::HEALTHY)
      expect(row[:given]["observations_count"]).to eq(4)
      expect(row[:kudos_mix]["display_ratio"]).to eq("3:1")
      expect(data[:spotlight_stats][:healthy_count]).to eq(1)
      expect(data[:spotlight_stats][:warning_count]).to eq(0)
    end

    it "maps Warning overall to ok spotlight bucket and treats missing EH as Needs Attention" do
      create_ogo_statuses(
        given_status: EngagementHealth::HEALTHY,
        received_status: EngagementHealth::WARNING,
        last_received_at: 45.days.ago
      )

      data = service.rows_and_spotlight_for("just_me")
      row = data[:rows].find { |r| r[:teammate].id == teammate.id }

      expect(row[:status]).to eq(:ok)
      expect(row[:overall_status]).to eq(EngagementHealth::WARNING)
      expect(data[:spotlight_stats][:warning_count]).to eq(1)
      expect(data[:spotlight_stats][:ok_count]).to eq(1)
    end

    it "uses Needs Attention when EngagementHealth rows are missing" do
      data = service.rows_and_spotlight_for("just_me")
      row = data[:rows].find { |r| r[:teammate].id == teammate.id }

      expect(row[:status]).to eq(:concerning)
      expect(row[:overall_status]).to eq(EngagementHealth::NEEDS_ATTENTION)
      expect(row[:given]["status"]).to eq(EngagementHealth::NEEDS_ATTENTION)
      expect(data[:spotlight_stats][:needs_attention_count]).to eq(1)
    end

    it "counts Given OGOs by Healthy/Warning/Needs Attention age bands" do
      create_ogo_statuses(
        given_status: EngagementHealth::HEALTHY,
        received_status: EngagementHealth::NEEDS_ATTENTION,
        last_received_at: nil
      )
      create(:observation, :published, company: organization, observer: person, published_at: 5.days.ago)
      create(:observation, :published, company: organization, observer: person, published_at: 45.days.ago)
      create(:observation, :published, company: organization, observer: person, published_at: 120.days.ago)

      data = service.rows_and_spotlight_for("just_me")
      row = data[:rows].find { |r| r[:teammate].id == teammate.id }

      expect(row[:given]["healthy_count"]).to eq(1)
      expect(row[:given]["warning_count"]).to eq(1)
      expect(row[:given]["needs_attention_count"]).to eq(1)
      expect(row[:given]["observations_count"]).to eq(3)
    end

    it "counts Received OGOs with the same HealthScopes rules as EngagementHealth" do
      other = create(:person)
      create_ogo_statuses(
        given_status: EngagementHealth::NEEDS_ATTENTION,
        received_status: EngagementHealth::WARNING,
        last_given_at: nil,
        last_received_at: 45.days.ago
      )

      [45.days.ago, 120.days.ago].each do |published_at|
        observation = build(:observation, :published, company: organization, observer: other, published_at: published_at)
        observation.observees = []
        observation.observees.build(teammate: teammate)
        observation.save!
      end

      data = service.rows_and_spotlight_for("just_me")
      row = data[:rows].find { |r| r[:teammate].id == teammate.id }

      expect(row[:received]["warning_count"]).to eq(1)
      expect(row[:received]["needs_attention_count"]).to eq(1)
      expect(row[:received]["observations_count"]).to eq(2)
    end
  end

  describe "#compact_spotlight_stats" do
    it "aliases Warning and Needs Attention into ok_count / concerning_count" do
      create_ogo_statuses(
        given_status: EngagementHealth::WARNING,
        received_status: EngagementHealth::WARNING,
        last_given_at: 40.days.ago,
        last_received_at: 40.days.ago
      )

      stats = service.compact_spotlight_stats("just_me")
      expect(stats[:ok_count]).to eq(1)
      expect(stats[:concerning_count]).to eq(0)
      expect(stats[:healthy_count]).to eq(0)
    end
  end
end
