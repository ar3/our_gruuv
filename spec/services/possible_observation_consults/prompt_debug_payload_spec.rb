# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationConsults::PromptDebugPayload do
  let(:organization) { create(:organization) }
  let(:creator) { create(:company_teammate, organization: organization) }
  let(:subject_tm) { create(:company_teammate, organization: organization) }
  let(:item_id) { SecureRandom.uuid }
  let(:ai_item) do
    {
      "id" => item_id,
      "kind" => "kudos",
      "quote" => "AI quote",
      "include" => true,
      "responder_company_teammate_id" => creator.id,
      "subject_company_teammate_id" => subject_tm.id
    }
  end
  let(:consult) do
    create(
      :possible_observation_consult,
      organization: organization,
      creator_company_teammate: creator,
      confirmed_teammate_ids: [subject_tm.id],
      people_status: "confirmed",
      extraction_status: "completed",
      extractions: {
        "version" => 1,
        "processed_teammate_ids" => [subject_tm.id],
        "ai_items" => [ai_item],
        "items" => [
          ai_item.merge("quote" => "Edited quote", "include" => true, "kind" => "feedback")
        ]
      }
    )
  end

  it "reports edited would_include with field changes" do
    payload = described_class.call(consult: consult)

    expect(payload[:purpose]).to eq("ogo_consult_prompt_debug")
    expect(payload[:counts][:would_include]).to eq(1)
    row = payload[:diff].first
    expect(row[:outcome]).to eq("would_include")
    expect(row[:field_changes]).to include(
      "quote" => { "from" => "AI quote", "to" => "Edited quote" },
      "kind" => { "from" => "kudos", "to" => "feedback" }
    )
  end
end
