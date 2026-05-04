# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AbilitiesHrReview::MarkdownNormalizer do
  it 'leaves a whole-line *italic* span unchanged (no space after the opening *)' do
    input = <<~MD
      *This is an italic line*
    MD
    expect(described_class.call(input)).to eq(input.strip)
  end

  it 'still normalizes a list line that starts with *word' do
    expect(described_class.call('*item')).to eq('* item')
  end

  it 'wraps horizontal rules and leaves italic lines alone in the same text' do
    input = <<~MD
      *Emphasized title*

      ***
    MD
    out = described_class.call(input)
    expect(out).to include('*Emphasized title*')
    expect(out).to include('***')
  end
end
