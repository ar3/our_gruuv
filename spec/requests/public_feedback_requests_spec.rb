# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public feedback requests', type: :request do
  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original_cache
  end

  let(:company) { create(:organization, :company, name: 'Acme Co') }
  let(:requestor) { create(:company_teammate, organization: company) }
  let(:subject_teammate) { create(:company_teammate, organization: company) }
  let(:feedback_request) do
    create(:feedback_request, :ready_open_link,
      company: company,
      requestor_teammate: requestor,
      subject_of_feedback_teammate: subject_teammate,
      subject_line: 'CSAT check-in',
      audience: :open_to_public
    )
  end
  let(:question) { feedback_request.feedback_request_questions.first }

  describe 'GET /f/:token' do
    it 'shows questions and an inline verify form for anonymous visitors' do
      get public_feedback_request_path(feedback_request.public_answer_token)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Feedback for')
      expect(response.body).to include(question.question_text)
      expect(response.body).to include('verify you are real')
      expect(response.body).to include('CSAT check-in') # in verify copy, not request-details card
      expect(response.body).not_to include('Request details')
      expect(response.body).to include('Phone number')
      expect(response.body).to include('Full name')
      expect(response.body).to include('Text me a code')
      expect(response.body).to include('Optional — defaults to Anonymous User')
      expect(response.body).to include('click here to sign in')
      expect(response.body).not_to include('save_and_complete')
    end

    it '404s when audience is not public' do
      feedback_request.update!(audience: :organization)
      get public_feedback_request_path(feedback_request.public_answer_token)
      expect(response).to have_http_status(:not_found)
    end

    it 'enables the form for a signed-in person and links to the org version for org teammates' do
      sign_in_as_teammate_for_request(requestor.person, company)
      get public_feedback_request_path(feedback_request.public_answer_token)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Request details')
      expect(response.body).to include('save_and_complete')
      expect(response.body).to include("You're signed in as a Acme Co teammate")
      expect(response.body).to include('Open the Acme Co teammate version')
      expect(response.body).not_to include('verify you are real')
    end

    it 'does not claim teammate status for a person-only session' do
      outsider = create(:person, first_name: 'Pat', last_name: 'External')
      sign_in_as_person_only_for_request(outsider)
      get public_feedback_request_path(feedback_request.public_answer_token)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('save_and_complete')
      expect(response.body).not_to include('teammate version')
      expect(response.body).not_to include("You're signed in as a Acme Co teammate")
    end

    it 'does not claim teammate status when session teammate is a different org' do
      other_org = create(:organization, :company, name: 'Other Co')
      outsider = create(:person)
      # Latent row for FR org must not trigger the banner if session is Other Co.
      create(:company_teammate, person: outsider, organization: company)
      sign_in_as_teammate_for_request(outsider, other_org)

      get public_feedback_request_path(feedback_request.public_answer_token)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('save_and_complete')
      expect(response.body).not_to include("You're signed in as a Acme Co teammate")
      expect(response.body).not_to include('Open the Acme Co teammate version')
    end
  end

  describe 'POST /f/:token/verify_start and verify' do
    it 'texts a code, then creates a person and unlocks the answer form' do
      phone = '+13175550199'
      post start_public_feedback_request_verification_path(feedback_request.public_answer_token),
           params: { full_name: 'Pat External', phone: phone }

      expect(response).to redirect_to(public_feedback_request_path(feedback_request.public_answer_token))
      follow_redirect!
      expect(response.body).to include('Text code')
      expect(response.body).to include('Verify and continue')

      code = Rails.cache.read("phone_otp:#{phone}")
      expect {
        post verify_public_feedback_request_path(feedback_request.public_answer_token),
             params: { code: code }
      }.to change(Person, :count).by(1)

      expect(response).to redirect_to(public_feedback_request_path(feedback_request.public_answer_token))
      person = Person.find_by_textable_phone(phone)
      expect(person.first_name).to eq('Pat')
      expect(person.last_name).to eq('External')
      expect(person.phone_verified?).to be true

      sign_in_as_person_only_for_request(person)
      get public_feedback_request_path(feedback_request.public_answer_token)
      expect(response.body).to include('save_and_complete')
    end

    it 'defaults blank name to Anonymous User' do
      phone = '+13175550198'
      post start_public_feedback_request_verification_path(feedback_request.public_answer_token),
           params: { full_name: '', phone: phone }
      code = Rails.cache.read("phone_otp:#{phone}")

      expect {
        post verify_public_feedback_request_path(feedback_request.public_answer_token),
             params: { code: code }
      }.to change(Person, :count).by(1)

      person = Person.find_by_textable_phone(phone)
      expect(person.first_name).to eq('Anonymous')
      expect(person.last_name).to eq('User')
    end

    it 'signs in an existing phone account without creating a new person' do
      phone = '+13175550200'
      existing = create(:person,
        first_name: 'Existing',
        last_name: 'User',
        unique_textable_phone_number: phone,
        phone_verified_at: 1.day.ago
      )

      post start_public_feedback_request_verification_path(feedback_request.public_answer_token),
           params: { full_name: 'Someone Else', phone: phone }
      code = Rails.cache.read("phone_otp:#{phone}")

      expect {
        post verify_public_feedback_request_path(feedback_request.public_answer_token),
             params: { code: code }
      }.not_to change(Person, :count)

      expect(response).to redirect_to(public_feedback_request_path(feedback_request.public_answer_token))
      expect(existing.reload.first_name).to eq('Existing')
    end
  end

  describe 'POST /f/:token' do
    it 'requires a person session' do
      post submit_public_feedback_request_path(feedback_request.public_answer_token),
           params: {
             save_and_complete: '1',
             answers: { question.id.to_s => { story: 'Great work.', rating: 'na' } }
           }

      expect(response).to redirect_to(login_path)
    end

    it 'creates an observation for a person-only session' do
      outsider = create(:person, first_name: 'Pat', last_name: 'External')
      sign_in_as_person_only_for_request(outsider)

      expect {
        post submit_public_feedback_request_path(feedback_request.public_answer_token),
             params: {
               save_and_complete: '1',
               answers: {
                 question.id.to_s => {
                   story: 'They were helpful and clear.',
                   rating: 'na',
                   privacy_level: 'observed_and_managers'
                 }
               }
             }
      }.to change(Observation, :count).by(1)

      expect(response).to redirect_to(me_path)
      follow_redirect!
      expect(response.body).to include('Me')
      expect(response.body).to include('More feedback to share?')
      expect(response.body).to include('Return to feedback')
      obs = Observation.last
      expect(obs.observer).to eq(outsider)
      expect(obs.company).to eq(company)
      expect(obs).to be_published
    end
  end
end
