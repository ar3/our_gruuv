# frozen_string_literal: true

require "rails_helper"

RSpec.describe SlackAbsoluteUrls do
  describe ".absolute" do
    it "returns https URLs unchanged" do
      expect(described_class.absolute("https://app.asana.com/task/1")).to eq("https://app.asana.com/task/1")
    end

    it "prefixes path-only URLs with host and protocol from url_options" do
      allow(described_class).to receive(:slack_url_options).and_return(host: "ourgruuv.com", protocol: "https")

      expect(described_class.absolute("/organizations/1/goals")).to eq("https://ourgruuv.com/organizations/1/goals")
    end

    it "returns blank strings unchanged" do
      expect(described_class.absolute("")).to eq("")
    end
  end
end
