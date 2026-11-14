# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::WeeklyOgoAnnouncement do
  let(:company) { create(:organization, :company) }
  let(:now) { Time.zone.parse("2026-11-14 12:00:00") } # Saturday
  let(:prev_week_mid) { Time.zone.parse("2026-11-05 12:00:00") } # Wed of previous Mon–Sun week
  let(:this_week) { Time.zone.parse("2026-11-12 12:00:00") }

  let(:observer) { create(:person, first_name: "Dana", last_name: "Giver") }
  let!(:observer_teammate) { create(:company_teammate, organization: company, person: observer) }
  let(:receiver) { create(:person, first_name: "Alex", last_name: "Receiver") }
  let!(:receiver_teammate) { create(:company_teammate, organization: company, person: receiver) }

  let(:assignment) { create(:assignment, company: company, title: "Ship Features") }
  let(:ability) { create(:ability, company: company, name: "Debugging") }
  let(:aspiration) { create(:aspiration, company: company, name: "Customer Love") }

  def publish_ogo(attrs = {})
    observee_teammate = attrs.delete(:observee_teammate) || receiver_teammate
    obs = build(
      :observation,
      :published,
      :public_to_company,
      {
        observer: observer,
        company: company,
        observed_at: prev_week_mid,
        story: "Story #{SecureRandom.hex(4)}"
      }.merge(attrs.except(:rating, :rateable, :created_as_type))
    )
    obs.observees = []
    obs.observees.build(teammate: observee_teammate)
    obs.created_as_type = attrs[:created_as_type] if attrs.key?(:created_as_type)
    obs.save!
    if attrs[:rateable]
      create(
        :observation_rating,
        observation: obs,
        rateable: attrs[:rateable],
        rating: attrs[:rating] || :agree
      )
    end
    obs
  end

  describe ".previous_week_range" do
    it "returns the prior Monday–Sunday week" do
      range = described_class.previous_week_range(now: now)
      expect(range.begin.to_date).to eq(Date.new(2026, 11, 2))
      expect(range.end.to_date).to eq(Date.new(2026, 11, 8))
    end
  end

  describe ".call" do
    it "returns quiet-week messaging when there are no published OGOs" do
      result = described_class.call(company: company, now: now)

      expect(result.total_count).to eq(0)
      expect(result.message_text).to include("Last week's OGOs")
      expect(result.message_text).to include("Quiet week")
      expect(result.message_text).to include("Nov 2")
      expect(result.message_text).to include("Nov 8, 2026")
    end

    it "builds Slack-ready copy with objects, people, and sources" do
      publish_ogo(rateable: assignment, rating: :agree)
      publish_ogo(rateable: ability, rating: :strongly_agree)
      publish_ogo(rateable: aspiration, rating: :agree)
      publish_ogo(
        rateable: assignment,
        rating: :disagree,
        created_as_type: Observation::CREATED_AS_SLACK_SOURCE
      )

      other_observer = create(:person, first_name: "Eve", last_name: "Also")
      create(:company_teammate, organization: company, person: other_observer)
      publish_ogo(observer: other_observer, rateable: assignment, rating: :agree)

      # Outside previous week — ignored
      publish_ogo(observed_at: this_week, rateable: assignment, rating: :agree)

      result = described_class.call(company: company, now: now)

      expect(result.total_count).to eq(5)
      expect(result.most_observed_assignment.name).to eq("Ship Features")
      expect(result.most_observed_assignment.count).to eq(3)
      expect(result.most_observed_ability.name).to eq("Debugging")
      expect(result.most_observed_aspiration.name).to eq("Customer Love")

      expect(result.top_recognized.first.name).to include("Alex")
      expect(result.top_recognized.first.count).to eq(4) # disagree OGO excluded for receivers

      expect(result.top_givers.first.name).to include("Dana")
      expect(result.top_givers.first.count).to eq(4)
      expect(result.top_givers.second.name).to include("Eve")

      expect(result.sources.map(&:name)).to include("Slack")
      expect(result.message_text).to include("We captured *5* observation stories")
      expect(result.message_text).to include("Ship Features")
      expect(result.message_text).to include("Teammates recognized (positive OGOs received)")
      expect(result.message_text).to include("Teammates who gave the most OGOs")
      expect(result.message_text).to include("Where OGOs came from")
      expect(result.message_text).to include("Add an OGO in OurGruuv")
    end

    it "does not name receivers for OGOs that only have non-positive ratings" do
      only_negative_receiver = create(:person, first_name: "Neg", last_name: "Only")
      only_negative_teammate = create(:company_teammate, organization: company, person: only_negative_receiver)
      publish_ogo(
        observee_teammate: only_negative_teammate,
        rateable: assignment,
        rating: :strongly_disagree
      )

      result = described_class.call(company: company, now: now)

      expect(result.total_count).to eq(1)
      expect(result.top_recognized).to be_empty
      expect(result.message_text).to include("No positive OGOs received")
      expect(result.top_givers.first.name).to include("Dana")
    end
  end
end
