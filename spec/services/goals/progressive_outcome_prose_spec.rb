# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::ProgressiveOutcomeProse do
  describe ".parse" do
    it "parses bracket form with baseline" do
      parsed = described_class.parse("Move retention from 50% to [60|70|80]%")
      expect(parsed.baseline).to eq(BigDecimal("50"))
      expect(parsed.commit).to eq(BigDecimal("60"))
      expect(parsed.stretch).to eq(BigDecimal("70"))
      expect(parsed.transform).to eq(BigDecimal("80"))
      expect(parsed.unit).to eq("%")
    end

    it "parses bare bracket form without baseline" do
      parsed = described_class.parse("Handle [1|2|3] requests coming from the insights queue")
      expect(parsed.baseline).to be_nil
      expect(parsed.commit).to eq(BigDecimal("1"))
      expect(parsed.stretch).to eq(BigDecimal("2"))
      expect(parsed.transform).to eq(BigDecimal("3"))
      expect(parsed.unit).to be_nil
    end

    it "parses bare two-band bracket form" do
      parsed = described_class.parse("Grow NPS to [40|55]")
      expect(parsed.baseline).to be_nil
      expect(parsed.commit).to eq(BigDecimal("40"))
      expect(parsed.stretch).to eq(BigDecimal("55"))
      expect(parsed.transform).to be_nil
    end

    it "parses labeled form" do
      parsed = described_class.parse(
        "We will move retention from 50% to Commit:60%, Stretch:70%, Transform:80%"
      )
      expect(parsed.baseline).to eq(BigDecimal("50"))
      expect(parsed.commit).to eq(BigDecimal("60"))
      expect(parsed.stretch).to eq(BigDecimal("70"))
      expect(parsed.transform).to eq(BigDecimal("80"))
    end

    it "parses paren stretch/transform form" do
      parsed = described_class.parse(
        "We will move retention from 50% to 60% (Stretch = 70% & Transform = 80%)"
      )
      expect(parsed.commit).to eq(BigDecimal("60"))
      expect(parsed.stretch).to eq(BigDecimal("70"))
      expect(parsed.transform).to eq(BigDecimal("80"))
    end
  end

  describe ".rewrite_after_hit" do
    it "drops commit from bracket form" do
      title = described_class.rewrite_after_hit(
        "Move retention from 50% to [60|70|80]%",
        hit_aim: "commit"
      )
      expect(title).to include("[70|80]")
      expect(title).not_to include("[60|70|80]")
    end
  end
end
