# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::OgScorecard::ClarityLevel do
  describe '.from_finalized_at' do
    let(:reference_time) { Time.zone.parse('2026-03-08 23:59:59') }

    it 'returns crystal_clear within 30 days' do
      finalized = reference_time - 10.days
      expect(described_class.from_finalized_at(finalized, reference_time: reference_time)).to eq(:crystal_clear)
    end

    it 'returns clear between 31 and 60 days' do
      finalized = reference_time - 45.days
      expect(described_class.from_finalized_at(finalized, reference_time: reference_time)).to eq(:clear)
    end

    it 'returns blurred between 61 and 90 days' do
      finalized = reference_time - 75.days
      expect(described_class.from_finalized_at(finalized, reference_time: reference_time)).to eq(:blurred)
    end

    it 'returns obscured beyond 90 days or when never finalized' do
      finalized = reference_time - 100.days
      expect(described_class.from_finalized_at(finalized, reference_time: reference_time)).to eq(:obscured)
      expect(described_class.from_finalized_at(nil, reference_time: reference_time)).to eq(:obscured)
    end
  end

  describe '.rollup_bucket' do
    it 'returns clear when empty (no required check-ins)' do
      expect(described_class.rollup_bucket([])).to eq(:clear)
    end

    it 'returns obscured when any item is obscured' do
      expect(described_class.rollup_bucket(%i[clear blurred obscured])).to eq(:obscured)
    end

    it 'returns blurred when any blurred and none obscured' do
      expect(described_class.rollup_bucket(%i[clear crystal_clear blurred])).to eq(:blurred)
    end

    it 'returns clear when all clear or crystal_clear' do
      expect(described_class.rollup_bucket(%i[clear crystal_clear])).to eq(:clear)
    end
  end
end
