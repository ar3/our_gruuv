# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::Billing::RoundDownToHalfDollar do
  it 'returns nil for nil' do
    expect(described_class.call(nil)).to be_nil
  end

  it 'returns zero below fifty cents' do
    expect(described_class.call(0)).to eq(0.0)
    expect(described_class.call(0.49)).to eq(0.0)
  end

  it 'keeps exact half-dollar amounts' do
    expect(described_class.call(0.50)).to eq(0.5)
    expect(described_class.call(1.50)).to eq(1.5)
  end

  it 'rounds down to the nearest half dollar' do
    expect(described_class.call(0.51)).to eq(0.5)
    expect(described_class.call(1.74)).to eq(1.5)
    expect(described_class.call(2.99)).to eq(2.5)
  end
end
