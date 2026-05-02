# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Maap::ClaritySignalParser do
  describe '.call' do
    it 'parses trailing CLARITY_SIGNAL and strips it from body' do
      raw = "Hello\n\nCLARITY_SIGNAL: GREEN\n"
      result = described_class.call(raw)
      expect(result.rating).to eq('green')
      expect(result.body).not_to match(/CLARITY_SIGNAL/)
    end

    it 'falls back from verdict when signal missing' do
      raw = "**Verdict** — Unclear."
      result = described_class.call(raw)
      expect(result.rating).to eq('red')
    end
  end
end
