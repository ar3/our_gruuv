# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::ObservationsSourcingChart do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:creator) { create(:company_teammate, organization: company, person: observer) }

  def published_observation(attrs = {})
    create(
      :observation,
      :published,
      :public_to_company,
      {
        observer: observer,
        company: company,
        observed_at: Time.current
      }.merge(attrs)
    )
  end

  describe ".bucket_label_for" do
    it "returns None when no source flags match" do
      obs = published_observation
      expect(described_class.bucket_label_for(obs)).to eq("None")
    end

    it "returns Feedback request when linked to a feedback request question" do
      fr = create(:feedback_request, company: company)
      question = create(:feedback_request_question, feedback_request: fr)
      obs = published_observation(feedback_request_question: question)
      expect(described_class.bucket_label_for(obs)).to eq("Feedback request")
    end

    it "returns Slack when created_as_type is slack_source" do
      obs = published_observation(created_as_type: Observation::CREATED_AS_SLACK_SOURCE)
      expect(described_class.bucket_label_for(obs)).to eq("Slack")
    end

    it "returns Consult OG when created_as_type is ogo_consult_source" do
      obs = published_observation(created_as_type: Observation::CREATED_AS_OGO_CONSULT)
      expect(described_class.bucket_label_for(obs)).to eq("Consult OG")
    end

    it "returns Observable moment when linked to a moment" do
      moment = create(:observable_moment, :new_hire, company: company, created_by: observer)
      obs = published_observation(observable_moment: moment)
      expect(described_class.bucket_label_for(obs)).to eq("Observable moment")
    end

    it "returns Goal when linked to a goal" do
      goal = create(:goal, creator: creator, owner: creator, company: company, started_at: 1.week.ago)
      obs = published_observation(goal: goal)
      expect(described_class.bucket_label_for(obs)).to eq("Goal")
    end

    it "returns a combination bucket when multiple flags match" do
      fr = create(:feedback_request, company: company)
      question = create(:feedback_request_question, feedback_request: fr)
      goal = create(:goal, creator: creator, owner: creator, company: company, started_at: 1.week.ago)
      obs = published_observation(feedback_request_question: question, goal: goal)
      expect(described_class.bucket_label_for(obs)).to eq("Feedback request + Goal")
    end
  end

  describe ".call" do
    it "builds pie points with combination and None buckets" do
      none = published_observation
      slack = published_observation(created_as_type: Observation::CREATED_AS_SLACK_SOURCE)
      fr = create(:feedback_request, company: company)
      question = create(:feedback_request_question, feedback_request: fr)
      goal = create(:goal, creator: creator, owner: creator, company: company, started_at: 1.week.ago)
      combo = published_observation(feedback_request_question: question, goal: goal)

      result = described_class.call([none, slack, combo])

      expect(result[:total]).to eq(3)
      expect(result[:counts]["None"]).to eq(1)
      expect(result[:counts]["Slack"]).to eq(1)
      expect(result[:counts]["Feedback request + Goal"]).to eq(1)
      expect(result[:pie].map { |p| p[:name] }).to include("None", "Slack", "Feedback request + Goal")
      expect(result[:pie].map { |p| p[:y] }.sum).to eq(3)
    end

    it "returns empty pie for no observations" do
      result = described_class.call([])
      expect(result[:total]).to eq(0)
      expect(result[:pie]).to eq([])
    end
  end
end
