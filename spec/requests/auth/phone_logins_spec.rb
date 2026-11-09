# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Phone logins', type: :request do
  let(:phone) { '+13175550199' }

  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original_cache
  end

  it 'verifies an existing unverified phone and signs the person in' do
    person = create(:person, unique_textable_phone_number: phone, phone_verified_at: nil)
    org = create(:organization, :company)
    create(:company_teammate, person: person, organization: org, first_employed_at: 1.year.ago)

    post auth_phone_login_path, params: { phone: phone }
    expect(response).to redirect_to(verify_auth_phone_login_path)
    code = Rails.cache.read("phone_otp:#{phone}")

    post verify_auth_phone_login_path, params: { phone: phone, code: code }
    expect(response).to redirect_to(root_path)
    expect(person.reload.phone_verified?).to eq(true)
    get me_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include('Verified')
  end

  it 'sends unknown phones to registration after OTP' do
    post auth_phone_login_path, params: { phone: phone }
    code = Rails.cache.read("phone_otp:#{phone}")
    post verify_auth_phone_login_path, params: { phone: phone, code: code }
    expect(response).to redirect_to(new_auth_phone_registration_path)
  end
end
