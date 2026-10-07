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

    it "frames the rating scale before the calibration explanation for :below_one" do
      html = described_class.rating_intensity_html(band: :below_one, subject_name: "Alex Rivera")
      expect(html).to include("When giving observations people can choose the range of")
      expect(html).to include("Exceptional")
      expect(html).to include("Strong")
      expect(html).to include("Mis-aligned")
      expect(html).to include("Concerning")
      expect(html).to include("People are more extreme when they are always choosing")
      expect(html).to include("Less extreme when it")
      expect(html).to include("calibration")
      expect(html.index("When giving observations")).to be < html.index("calibration")
    end
  end

  describe ".rating_intensity_scale_intro_html" do
    it "explains the rating range and what more vs less extreme means" do
      html = described_class.rating_intensity_scale_intro_html
      expect(html).to include("assignment / ability / or value")
      expect(html).to include("more extreme")
      expect(html).to include("Less extreme")
    end
  end
end
