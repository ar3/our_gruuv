# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PhoneOtp do
  around do |example|
    original_env = ENV['PHONE_OTP_SKIP_SMS']
    original_cache = Rails.cache
    ENV['PHONE_OTP_SKIP_SMS'] = nil # default test skip
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    ENV['PHONE_OTP_SKIP_SMS'] = original_env
    Rails.cache = original_cache
  end

  it 'sends and verifies a code for a phone' do
    send_result = described_class.send_code!(phone: '3175550100')
    expect(send_result).to be_ok
    expect(send_result.debug_code).to be_present

    bad = described_class.verify_code!(phone: send_result.phone, code: '000000')
    expect(bad).not_to be_ok

    good = described_class.verify_code!(phone: send_result.phone, code: send_result.debug_code)
    expect(good).to be_ok
    expect(good.phone).to eq('+13175550100')
  end
end
