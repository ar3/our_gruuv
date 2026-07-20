# frozen_string_literal: true

require "rails_helper"

RSpec.describe Zoom::ListTranscriptsService do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let!(:identity) { create(:teammate_identity, :zoom, teammate: teammate) }

  it "returns meetings that include a TRANSCRIPT file" do
    client = instance_double(Zoom::OauthClient, authenticated?: true)
    allow(Zoom::OauthClient).to receive(:new).with(teammate).and_return(client)
    allow(client).to receive(:get_json).with(
      "/users/me/recordings",
      params: hash_including(:from, :to, :page_size)
    ).and_return(
      "meetings" => [
        {
          "id" => 123,
          "uuid" => "abc==",
          "topic" => "Weekly sync",
          "start_time" => "2026-07-10T15:00:00Z",
          "recording_files" => [
            {
              "id" => "file1",
              "file_type" => "MP4",
              "download_url" => "https://zoom.us/rec/download/video"
            },
            {
              "id" => "file2",
              "file_type" => "TRANSCRIPT",
              "recording_type" => "audio_transcript",
              "download_url" => "https://zoom.us/rec/download/transcript"
            }
          ]
        }
      ]
    )

    rows = described_class.call(teammate: teammate)
    expect(rows.size).to eq(1)
    expect(rows.first.download_url).to include("transcript")
    expect(rows.first.display_name).to include("Weekly sync")
  end
end

RSpec.describe Zoom::DownloadTranscriptService do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let!(:identity) { create(:teammate_identity, :zoom, teammate: teammate) }

  it "downloads and strips VTT to plaintext" do
    client = instance_double(Zoom::OauthClient, authenticated?: true)
    allow(Zoom::OauthClient).to receive(:new).with(teammate).and_return(client)
    allow(client).to receive(:get_body).with("https://zoom.us/rec/download/transcript").and_return(<<~VTT)
      WEBVTT

      00:00:01.000 --> 00:00:04.000
      Pat: great work on the launch.
    VTT

    text = described_class.call(
      teammate: teammate,
      download_url: "https://zoom.us/rec/download/transcript"
    )
    expect(text).to include("Pat: great work on the launch.")
    expect(text).not_to include("WEBVTT")
    expect(text).not_to include("-->")
  end
end
