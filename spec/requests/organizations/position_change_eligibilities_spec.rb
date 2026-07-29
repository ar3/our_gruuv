# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::PositionChangeEligibilities', type: :request do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:company_teammate, :unassigned_employee, person: person, organization: organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let!(:position) { create(:position, title: title, position_level: position_level) }

  before do
    sign_in_as_teammate_for_request(person, organization)
    PaperTrail.enabled = false
  end

  after do
    PaperTrail.enabled = true
  end

  describe 'POST run' do
    it 'creates a consultation and enqueues the job' do
      expect do
        post run_position_change_eligibility_organization_eligibility_requirement_path(
          organization,
          position,
          teammate_id: teammate.id
        )
      end.to change(OgConsultation, :count).by(1)
        .and have_enqueued_job(PositionChangeEligibilityJob)

      consultation = OgConsultation.order(:id).last
      expect(consultation.kind).to eq(OgConsultation::KIND_POSITION_CHANGE_ELIGIBILITY)
      expect(consultation.billable).to eq(true)
      expect(consultation.subject).to eq(teammate)
      expect(consultation.position_change_eligibility_result.position).to eq(position)
      expect(response).to redirect_to(
        organization_eligibility_requirement_path(
          organization,
          position,
          teammate_id: teammate.id,
          consultation_id: consultation.id
        )
      )
    end
  end

  describe 'GET status' do
    it 'returns JSON for the latest consultation' do
      create_position_change_eligibility_consultation!(
        teammate: teammate,
        position: position,
        organization: organization,
        status: 'processing'
      )

      get position_change_eligibility_status_organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('processing')
    end
  end

  describe 'GET eligibility show with consult UI' do
    it 'includes the Consult OG section collapsed by default' do
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Consult OG — Position-Change Eligibility')
      expect(response.body).to include('OG will never give the final recommendation')
      expect(response.body).to include('id="pceConsultBody"')
      expect(response.body).to include('data-bs-target="#pceConsultBody"')
      expect(response.body).to include('class="card-body collapse eligibility-section-collapse-body"')
    end

    it 'shows completed shared output and private placeholders' do
      consultation = create_position_change_eligibility_consultation!(
        teammate: teammate,
        position: position,
        organization: organization,
        status: 'completed',
        completed_at: Time.current,
        output_text: 'Shared analysis body.',
        manager_only_ran: true,
        manager_only_output_text: 'Manager secret.',
        teammate_only_ran: true,
        teammate_only_output_text: 'Teammate secret.'
      )

      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id,
        consultation_id: consultation.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Shared analysis body.')
      expect(response.body).to include('Teammate secret.')
      expect(response.body).to include('For managers only')
      expect(response.body).not_to include('Manager secret.')
      expect(response.body).to include('class="card-body collapse eligibility-section-collapse-body show"')
    end
  end
end
