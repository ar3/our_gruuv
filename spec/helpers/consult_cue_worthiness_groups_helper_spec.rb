# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#consult_cue_worthiness_groups" do
    it "splits consecutive worthy and unworthy runs" do
      cues = [
        { "id" => "1", "start" => "00:01:00.000", "speaker_label" => "Alex" },
        { "id" => "2", "start" => "00:01:10.000", "speaker_label" => "Alex" },
        { "id" => "3", "start" => "00:02:00.000", "speaker_label" => "Pat" },
        { "id" => "4", "start" => "00:03:00.000", "speaker_label" => "Pat" }
      ]
      annotations = {
        "1" => { "ogo_worthy" => false },
        "2" => { "ogo_worthy" => false },
        "3" => { "ogo_worthy" => true },
        "4" => { "ogo_worthy" => false }
      }

      groups = helper.consult_cue_worthiness_groups(cues, annotations)

      expect(groups.map { |g| [g[:worthy], g[:cues].map { |c| c[:id] }] }).to eq([
        [false, %w[1 2]],
        [true, %w[3]],
        [false, %w[4]]
      ])
    end
  end

  describe "#consult_unworthy_cue_group_summary" do
    it "summarizes time range, count, and speakers" do
      cues = [
        { "id" => "1", "start" => "00:01:00.000", "end" => "00:01:05.000", "speaker_label" => "Alex" },
        { "id" => "2", "start" => "00:01:10.000", "end" => "00:01:20.000", "speaker_label" => "Pat" }
      ]

      expect(helper.consult_unworthy_cue_group_summary(cues)).to eq(
        "From 00:01:00.000 to 00:01:20.000, 2 non-OGO-worthy cues (Alex and Pat). Expand to review."
      )
    end
  end
end
