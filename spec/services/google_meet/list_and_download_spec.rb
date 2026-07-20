# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoogleMeet::ListTranscriptsService do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let!(:identity) { create(:teammate_identity, :google_meet, teammate: teammate) }

  it "returns FILE_GENERATED transcripts with document ids" do
    client = instance_double(GoogleMeet::OauthClient, authenticated?: true)
    allow(GoogleMeet::OauthClient).to receive(:new).with(teammate).and_return(client)

    allow(client).to receive(:get_json).with(
      "https://meet.googleapis.com/v2/conferenceRecords",
      params: hash_including(:pageSize, :filter)
    ).and_return(
      "conferenceRecords" => [
        {
          "name" => "conferenceRecords/abc",
          "startTime" => "2026-07-10T15:00:00Z",
          "endTime" => "2026-07-10T16:00:00Z"
        }
      ]
    )
    allow(client).to receive(:get_json).with(
      "https://meet.googleapis.com/v2/conferenceRecords/abc/transcripts",
      params: { pageSize: 10 }
    ).and_return(
      "transcripts" => [
        {
          "name" => "conferenceRecords/abc/transcripts/t1",
          "state" => "FILE_GENERATED",
          "docsDestination" => {
            "document" => "doc123",
            "exportUri" => "https://docs.google.com/document/d/doc123"
          }
        },
        {
          "name" => "conferenceRecords/abc/transcripts/t2",
          "state" => "STARTED",
          "docsDestination" => { "document" => "doc456" }
        }
      ]
    )

    rows = described_class.call(teammate: teammate)
    expect(rows.size).to eq(1)
    expect(rows.first.document_id).to eq("doc123")
    expect(rows.first.conference_record_name).to eq("conferenceRecords/abc")
    expect(rows.first.display_name).to include("Meet transcript")
  end
end

RSpec.describe GoogleMeet::DownloadTranscriptService do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let!(:identity) { create(:teammate_identity, :google_meet, teammate: teammate) }

  it "exports the Docs transcript as plaintext" do
    client = instance_double(GoogleMeet::OauthClient, authenticated?: true)
    allow(GoogleMeet::OauthClient).to receive(:new).with(teammate).and_return(client)
    allow(client).to receive(:get_body).with(
      "https://www.googleapis.com/drive/v3/files/doc123/export",
      params: { mimeType: "text/plain" }
    ).and_return("Pat: great work on the launch.")

    text = described_class.call(teammate: teammate, document_id: "doc123")
    expect(text).to eq("Pat: great work on the launch.")
  end
end
