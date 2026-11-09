# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Me page', type: :request do
  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original_cache
  end

  it 'requires authentication' do
    get me_path
    expect(response).to redirect_to(login_path)
  end

  it 'allows a person-only session without a teammate after phone registration' do
    phone = '+13175550300'
    post auth_phone_login_path, params: { phone: phone }
    code = Rails.cache.read("phone_otp:#{phone}")
    post verify_auth_phone_login_path, params: { phone: phone, code: code }
    post auth_phone_registration_path, params: {
      person: { first_name: 'Sam', last_name: 'Guest', email: 'sam.guest@example.com' }
    }
    expect(response).to redirect_to(me_path)
    follow_redirect!
    expect(response).to have_http_status(:success)
    expect(response.body).to include('Me')
    expect(response.body).to include('+13175550300')
    expect(response.body).to include('Verified')
    expect(response.body).to match(/don.t have any organization teammate/)
  end
end
