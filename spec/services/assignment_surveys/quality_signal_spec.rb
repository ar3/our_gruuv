require "rails_helper"

RSpec.describe AssignmentSurveys::QualitySignal do
  def signal_for(average:, counts: {}, total: nil)
    described_class.from_distribution(
      average: average,
      counts: counts,
      total: total || counts.values.sum
    )
  end

  describe ".band_for" do
    it "maps averages to opinionated bands" do
      expect(described_class.band_for(1.99)[:key]).to eq(:critical)
      expect(described_class.band_for(2.0)[:key]).to eq(:poor)
      expect(described_class.band_for(2.99)[:key]).to eq(:poor)
      expect(described_class.band_for(3.0)[:key]).to eq(:concerning)
      expect(described_class.band_for(3.99)[:key]).to eq(:concerning)
      expect(described_class.band_for(4.0)[:key]).to eq(:strained)
      expect(described_class.band_for(4.99)[:key]).to eq(:strained)
      expect(described_class.band_for(5.0)[:key]).to eq(:healthy)
      expect(described_class.band_for(5.49)[:key]).to eq(:healthy)
      expect(described_class.band_for(5.5)[:key]).to eq(:incredible)
      expect(described_class.band_for(6.0)[:key]).to eq(:incredible)
    end

    it "returns nil without an average" do
      expect(described_class.band_for(nil)).to be_nil
    end
  end

  describe ".from_distribution" do
    it "returns nil without an average" do
      expect(described_class.from_distribution(average: nil, counts: { 1 => 0 }, total: 0)).to be_nil
    end

    it "counts dissent from ratings 1–3 and flags caution on positive bands" do
      signal = signal_for(
        average: 5.2,
        counts: { 1 => 1, 2 => 0, 3 => 1, 4 => 0, 5 => 5, 6 => 1 }
      )

      expect(signal.key).to eq(:healthy)
      expect(signal.label).to eq("Healthy")
      expect(signal.dissent_count).to eq(2)
      expect(signal.show_caution?).to be(true)
      expect(signal.small_sample?).to be(false)
    end

    it "does not show caution when a healthy average has no dissent" do
      signal = signal_for(average: 5.0, counts: { 5 => 4, 6 => 0 })

      expect(signal.show_caution?).to be(false)
      expect(signal.dissent_count).to eq(0)
    end

    it "does not show caution on non-positive bands even with dissent" do
      signal = signal_for(average: 4.2, counts: { 3 => 2, 4 => 5, 5 => 1 })

      expect(signal.key).to eq(:strained)
      expect(signal.dissent_count).to eq(2)
      expect(signal.show_caution?).to be(false)
    end

    it "flags small samples under three responses" do
      signal = signal_for(average: 5.8, counts: { 6 => 2 }, total: 2)

      expect(signal.key).to eq(:incredible)
      expect(signal.small_sample?).to be(true)
    end

    it "does not flag small sample at three responses" do
      signal = signal_for(average: 5.0, counts: { 5 => 3 }, total: 3)

      expect(signal.small_sample?).to be(false)
    end
  end
end
