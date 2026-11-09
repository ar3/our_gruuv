# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PhoneNumberNormalizer do
  it 'normalizes US 10-digit numbers' do
    expect(described_class.call('(317) 555-0100')).to eq('+13175550100')
  end

  it 'treats plus + 10 digits as US missing country code' do
    expect(described_class.call('+3172866905')).to eq('+13172866905')
  end

  it 'keeps longer international E.164 with plus' do
    expect(described_class.call('+44 7911 123456')).to eq('+447911123456')
  end

  it 'returns nil for blank' do
    expect(described_class.call('')).to be_nil
  end

  it 'builds lookup candidates that include legacy 10-digit and mistaken-plus forms' do
    expect(described_class.lookup_candidates('3172866905')).to include(
      '+13172866905',
      '3172866905',
      '13172866905',
      '+3172866905'
    )
    expect(described_class.lookup_candidates('+13172866905')).to include('+3172866905', '3172866905')
  end
end


