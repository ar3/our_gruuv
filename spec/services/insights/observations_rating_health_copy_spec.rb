# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::ObservationsRatingHealthCopy do
  describe ".kudos_constructive_html" do
    it "returns healthy copy for :healthy band" do
      html = described_class.kudos_constructive_html(band: :healthy, subject_name: "Alex Rivera")
      expect(html).to include("Alex Rivera")
      expect(html).to include("healthy mix")
    end

    it "returns no_data copy when band is no_data" do
      html = described_class.kudos_constructive_html(band: :no_data, subject_name: "Alex Rivera")
      expect(html).to include("Not enough published OGOs")
    end
  end

  describe ".rating_intensity_html" do
    it "returns healthy copy for :healthy band" do
      html = described_class.rating_intensity_html(band: :healthy, subject_name: "Alex Rivera")
      expect(html).to include("healthy balance")
    end
  end
end
