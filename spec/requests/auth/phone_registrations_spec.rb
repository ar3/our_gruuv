# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Phone registrations', type: :request do
  let(:phone) { '+13175550200' }

  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original_cache
  end

  def complete_otp_for_unknown_phone!
    post auth_phone_login_path, params: { phone: phone }
    code = Rails.cache.read("phone_otp:#{phone}")
    post verify_auth_phone_login_path, params: { phone: phone, code: code }
    expect(response).to redirect_to(new_auth_phone_registration_path)
    follow_redirect!
  end

  it 'creates a person-only account for a new email' do
    complete_otp_for_unknown_phone!

    expect do
      post auth_phone_registration_path, params: {
        person: { first_name: 'Pat', last_name: 'Lee', email: 'pat.lee@example.com' }
      }
    end.to change(Person, :count).by(1)

    expect(response).to redirect_to(me_path)
    person = Person.find_by_email_insensitive('pat.lee@example.com')
    expect(person.unique_textable_phone_number).to eq(phone)
    expect(person.phone_verified?).to eq(true)

    follow_redirect!
    expect(response).to have_http_status(:success)
    expect(response.body).to include('Verified')
  end

  it 'refuses when email already exists and points to Google' do
    create(:person, email: 'taken@example.com')
    complete_otp_for_unknown_phone!

    expect do
      post auth_phone_registration_path, params: {
        person: { first_name: 'Pat', last_name: 'Lee', email: 'taken@example.com' }
      }
    end.not_to change(Person, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('Sign in with Google')
    expect(response.body).to include('add this phone on your profile')
  end
end
