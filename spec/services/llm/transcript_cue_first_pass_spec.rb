# frozen_string_literal: true

require "rails_helper"

RSpec.describe Llm::TranscriptCueFirstPass do
  let(:organization) { create(:organization) }
  let(:natalie) { create(:person, full_name: "Natalie Morgan", preferred_name: "Natalie") }
  let!(:natalie_tm) { create(:company_teammate, person: natalie, organization: organization, first_employed_at: 1.year.ago) }
  let(:brett) { create(:person, full_name: "Brett Example", preferred_name: "Brett") }
  let!(:brett_tm) { create(:company_teammate, person: brett, organization: organization, first_employed_at: 1.year.ago) }
  let(:kayla) { create(:person, full_name: "Kayla Example", preferred_name: "Kayla") }
  let!(:kayla_tm) { create(:company_teammate, person: kayla, organization: organization, first_employed_at: 1.year.ago) }
  let(:amy) { create(:person, full_name: "Amy Example", preferred_name: "Amy") }
  let!(:amy_tm) { create(:company_teammate, person: amy, organization: organization, first_employed_at: 1.year.ago) }

  let(:long_text) do
    "Alright, a few. First, for, Kayla and Nicole. been meeting with them. " \
      "So, Kayla and Nicole, I appreciate you. Let's go. Couple more… Well, let me just go to the one, which is Amy. " \
      "Y'all, I work with Amy pretty closely, these days, and the thing that I wanted to shout out Amy for… " \
      "She cares so freaking much about each and every one of you. Appreciator."
  end

  let(:cues) do
    [
      {
        "id" => "cue-1",
        "start" => "00:12:00.000",
        "speaker_label" => "Natalie Morgan",
        "kind" => "speech",
        "text" => long_text
      }
    ]
  end

  it "slices multi-moment excerpts from the original cue using verbatim anchors" do
    allow(Llm::Client).to receive(:call).and_return(
      double(
        content: {
          cues: [
            {
              id: "cue-1",
              moments: [
                {
                  ogo_worthy: true,
                  anchor: "First, for, Kayla and Nicole.",
                  observer_label: "Natalie Morgan",
                  observee_labels: %w[Kayla Nicole],
                  observer_company_teammate_id: natalie_tm.id,
                  observee_company_teammate_ids: [kayla_tm.id],
                  reason: "Kayla Nicole"
                },
                {
                  ogo_worthy: true,
                  anchor: "which is Amy.",
                  observer_label: "Natalie Morgan",
                  observee_labels: ["Amy"],
                  observer_company_teammate_id: natalie_tm.id,
                  observee_company_teammate_ids: [amy_tm.id],
                  reason: "Amy"
                }
              ]
            }
          ]
        }.to_json
      )
    )

    results = described_class.call(
      cues: cues,
      organization_id: organization.id,
      teammates: [natalie_tm, brett_tm, kayla_tm, amy_tm]
    )

    expect(Llm::Client).to have_received(:call) do |kwargs|
      expect(kwargs[:system_instructions]).to include("STAY FAITHFUL TO THE TRANSCRIPT")
      expect(kwargs[:prompt_version]).to eq("1.20261031.3")
    end

    moments = results["cue-1"]["moments"]
    expect(moments.size).to eq(2)
    expect(moments.first["excerpt"]).to include("Kayla and Nicole")
    expect(moments.first["excerpt"]).not_to include("which is Amy")
    expect(moments.last["excerpt"]).to include("Amy")
    expect(moments.last["excerpt"]).to include("Appreciator")
    expect(long_text).to include(moments.first["excerpt"])
    expect(long_text).to include(moments.last["excerpt"])
  end

  it "falls back to discourse-marker slices when anchors are invented" do
    allow(Llm::Client).to receive(:call).and_return(
      double(
        content: {
          cues: [
            {
              id: "cue-1",
              moments: [
                {
                  ogo_worthy: true,
                  anchor: "Totally invented opening that is not in the transcript at all.",
                  observee_labels: %w[Kayla Nicole],
                  reason: "Kayla Nicole"
                },
                {
                  ogo_worthy: true,
                  anchor: "Totally invented praise about someone else later in the meeting.",
                  observee_labels: ["Amy"],
                  reason: "Amy"
                }
              ]
            }
          ]
        }.to_json
      )
    )

    moments = described_class.call(
      cues: cues,
      organization_id: organization.id,
      teammates: [natalie_tm, kayla_tm, amy_tm]
    ).fetch("cue-1").fetch("moments")

    expect(moments.size).to eq(2)
    expect(moments.first["excerpt"]).to include("Kayla")
    expect(moments.last["excerpt"]).to include("Amy")
    expect(moments.map { |m| m["reason"].to_s }).to all(include("split_by_discourse_marker"))
  end
end

