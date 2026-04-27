# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::PossibleObservationTranscripts', type: :request do
  let(:company) { create(:organization) }
  let(:creator) { create(:company_teammate, :unassigned_employee, organization: company) }
  let(:other_teammate) { create(:company_teammate, :unassigned_employee, organization: company) }

  before do
    sign_in_as_teammate_for_request(creator.person, company)
  end

  describe 'GET /organizations/:organization_id/possible_observation_transcripts' do
    let!(:transcript) do
      create(:possible_observation_transcript, :completed, organization: company, creator_company_teammate: creator,
                                                          display_name: 'All-hands')
    end

    it 'renders index for any teammate' do
      get organization_possible_observation_transcripts_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('All-hands')
    end

    it 'filters to my transcripts when mine=1' do
      other = create(:possible_observation_transcript, :completed, organization: company,
                                                                   creator_company_teammate: other_teammate,
                                                                   display_name: 'Other upload')

      get organization_possible_observation_transcripts_path(company, mine: '1')
      expect(response.body).to include('All-hands')
      expect(response.body).not_to include('Other upload')
    end
  end

  describe 'GET show' do
    let!(:transcript) do
      create(:possible_observation_transcript, :completed, organization: company, creator_company_teammate: creator)
    end

    it 'allows the creator to view' do
      get organization_possible_observation_transcript_path(company, transcript)
      expect(response).to have_http_status(:success)
    end

    it 'denies other teammates' do
      sign_in_as_teammate_for_request(other_teammate.person, company)
      get organization_possible_observation_transcript_path(company, transcript)
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'POST create' do
    it 'creates a transcript and enqueues extraction' do
      allow(PossibleObservationTranscriptExtractionJob).to receive(:perform_later)
      expect do
        post organization_possible_observation_transcripts_path(company), params: {
          possible_observation_transcript: {
            display_name: 'Sprint retro',
            transcript_file: fixture_file_upload('transcript_sample.txt', 'text/plain')
          }
        }
      end.to change(PossibleObservationTranscript, :count).by(1)

      expect(response).to redirect_to(
        organization_possible_observation_transcript_path(company, PossibleObservationTranscript.last)
      )
      expect(PossibleObservationTranscriptExtractionJob).to have_received(:perform_later).once
    end
  end
end
