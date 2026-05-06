# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Maap::AssignmentClarityOutputParser do
  describe '.call' do
    it 'parses CLARITY_SCORE_TOTAL and CLARITY_SIGNAL; strips both; rating from score (80/60 bands)' do
      raw = <<~TEXT.strip
        **Verdict** — Mostly clear.

        CLARITY_SCORE_TOTAL: 72
        CLARITY_SIGNAL: GREEN
      TEXT

      result = described_class.call(raw)
      expect(result.score).to eq(72)
      expect(result.rating).to eq('yellow') # strict: total drives signal, not model line
      expect(result.body).not_to match(/CLARITY_SCORE_TOTAL|CLARITY_SIGNAL/)
      expect(result.recommendations).to eq([])
    end

    it 'clamps score to 0–100' do
      raw = "x\n\nCLARITY_SCORE_TOTAL: 150\nCLARITY_SIGNAL: YELLOW\n"
      expect(described_class.call(raw).score).to eq(100)
    end

    it 'parses score-only trailing line' do
      raw = "Done.\nCLARITY_SCORE_TOTAL: 45\n"
      result = described_class.call(raw)
      expect(result.score).to eq(45)
      expect(result.rating).to eq('red')
      expect(result.body).not_to match(/CLARITY_SCORE_TOTAL/)
    end

    it 'falls back to legacy signal-only output' do
      raw = "Hello\n\nCLARITY_SIGNAL: GREEN\n"
      result = described_class.call(raw)
      expect(result.score).to be_nil
      expect(result.rating).to eq('green')
      expect(result.body).not_to match(/CLARITY_SIGNAL/)
      expect(result.recommendations).to eq([])
    end

    it 'strips BEGIN/END recommendations block and parses array before score lines' do
      raw = <<~TEXT.strip
        Summary here.

        BEGIN_MAAP_RECOMMENDATIONS
        [{"id":"rec1","confidence":"high","kind":"edit_tagline","title":"T","rationale":"R","payload":{}}]
        END_MAAP_RECOMMENDATIONS

        CLARITY_SCORE_TOTAL: 85
        CLARITY_SIGNAL: RED
      TEXT

      result = described_class.call(raw)
      expect(result.score).to eq(85)
      expect(result.rating).to eq('green')
      expect(result.recommendations.size).to eq(1)
      expect(result.recommendations.first['id']).to eq('rec1')
      expect(result.body).not_to match(/BEGIN_MAAP_RECOMMENDATIONS|CLARITY_SCORE_TOTAL/)
    end
  end

  describe '.rating_from_score' do
    it 'maps bands' do
      expect(described_class.rating_from_score(100)).to eq('green')
      expect(described_class.rating_from_score(80)).to eq('green')
      expect(described_class.rating_from_score(79)).to eq('yellow')
      expect(described_class.rating_from_score(60)).to eq('yellow')
      expect(described_class.rating_from_score(59)).to eq('red')
      expect(described_class.rating_from_score(0)).to eq('red')
    end
  end
end
