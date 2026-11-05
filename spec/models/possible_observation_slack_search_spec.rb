# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationSlackSearch, type: :model do
  describe "#extraction_prompt_stale?" do
    let(:organization) { create(:organization, :company) }
    let(:creator) { create(:company_teammate, :assigned_employee, organization: organization) }
    let(:subject_teammate) { create(:company_teammate, :assigned_employee, organization: organization) }

    it "is true when a completed batch used an older prompt version" do
      search = create(
        :possible_observation_slack_search,
        :extracted,
        organization: organization,
        creator_company_teammate: creator,
        subject_company_teammate: subject_teammate
      )
      batch = search.message_batches.first
      batch.update!(extractions: batch.extractions.merge("prompt_version" => "1.20260101.0"))

      expect(search.extraction_prompt_stale?).to eq(true)
    end

    it "is false when every completed batch matches the current prompt version" do
      search = create(
        :possible_observation_slack_search,
        :extracted,
        organization: organization,
        creator_company_teammate: creator,
        subject_company_teammate: subject_teammate
      )
      batch = search.message_batches.first
      batch.update!(
        extractions: batch.extractions.merge(
          "prompt_version" => Llm::SlackMomentsExtractor::PROMPT_VERSION
        )
      )

      expect(search.extraction_prompt_stale?).to eq(false)
    end
  end
end
