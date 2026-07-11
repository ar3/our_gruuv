# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::OgScorecard::ThresholdsForCompany do
  let(:company) { create(:organization, :company) }

  describe ".call" do
    it "returns registry keys and prunes stale metric threshold rows" do
      stale = OgScorecardMetricThreshold.new(
        company: company,
        metric_key: "all_check_ins_clear",
        yellow_threshold: 1,
        green_threshold: 2,
        threshold_mode: "absolute"
      )
      stale.save!(validate: false)

      result = described_class.call(company)

      expect(result.keys).to match_array(Insights::OgScorecard::MetricRegistry.keys)
      expect(OgScorecardMetricThreshold.where(id: stale.id)).not_to exist
      expect(result).not_to have_key("all_check_ins_clear")
    end
  end
end
