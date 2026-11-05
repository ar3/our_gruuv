# frozen_string_literal: true

require "rails_helper"

RSpec.describe SlackPossibleObservation, type: :model do
  describe "#suggested_association_chip" do
    it "builds a short type · name · rating chip and maps Aspiration to Value" do
      moment = build(
        :slack_possible_observation,
        payload: {
          "suggested_rateable_type" => "Aspiration",
          "suggested_rateable_name" => "Customer love",
          "suggested_rating" => "strongly_agree"
        }
      )

      expect(moment.suggested_association_chip).to eq("Value · Customer love · Exceptional")
    end

    it "returns nil when no suggestion fields are present" do
      moment = build(:slack_possible_observation, payload: { "summary" => "No suggestion" })
      expect(moment.suggested_association_chip).to be_nil
    end
  end
end
