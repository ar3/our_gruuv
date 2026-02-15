require 'rails_helper'

RSpec.describe 'Organizations::Insights', type: :request do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, person: person, organization: organization, first_employed_at: 1.year.ago) }

  before do
    sign_in_as_teammate_for_request(person, organization)
    allow_any_instance_of(OrganizationPolicy).to receive(:view_observations?).and_return(true)
  end

  describe 'GET /organizations/:organization_id/insights/observations' do
    it 'returns http success' do
      get organization_insights_observations_path(organization)
      expect(response).to have_http_status(:success)
    end

    it 'renders observations insights page with chart and tables' do
      get organization_insights_observations_path(organization)
      expect(response.body).to include('Insights: Observations')
      expect(response.body).to include('Observations Kudos vs Feedback')
      expect(response.body).to include('Observations Sharing')
      expect(response.body).to include('observations-by-privacy-chart')
    end

    it 'includes timeframe filter links (Last 90 days, Last Year, All-Time)' do
      get organization_insights_observations_path(organization)
      expect(response.body).to include('Last 90 days')
      expect(response.body).to include('Last Year')
      expect(response.body).to include('All-Time')
    end

    it 'returns success with timeframe=year' do
      get organization_insights_observations_path(organization, timeframe: 'year')
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /organizations/:organization_id/insights/feedback_requests' do
    before do
      allow_any_instance_of(OrganizationPolicy).to receive(:view_feedback_requests?).and_return(true)
    end

    it 'returns http success' do
      get organization_insights_feedback_requests_path(organization)
      expect(response).to have_http_status(:success)
    end

    it 'renders feedback requests insights page with timeframe links' do
      get organization_insights_feedback_requests_path(organization)
      expect(response.body).to include('Insights: Feedback Requests')
      expect(response.body).to include('Last 90 days')
      expect(response.body).to include('Last Year')
      expect(response.body).to include('All-Time')
    end

    it 'returns success with timeframe=year' do
      get organization_insights_feedback_requests_path(organization, timeframe: 'year')
      expect(response).to have_http_status(:success)
    end

    it 'returns success with timeframe=all_time' do
      get organization_insights_feedback_requests_path(organization, timeframe: 'all_time')
      expect(response).to have_http_status(:success)
    end

    it 'includes the feedback requests created chart container' do
      get organization_insights_feedback_requests_path(organization)
      expect(response.body).to include('feedback-requests-created-chart')
    end

    it 'includes the feedback observations published chart container' do
      get organization_insights_feedback_requests_path(organization)
      expect(response.body).to include('feedback-observations-published-chart')
    end

    it 'includes top 10 feedback givers, assignments, and abilities sections' do
      get organization_insights_feedback_requests_path(organization)
      expect(response.body).to include('Top 10 Feedback Givers')
      expect(response.body).to include('Top 10 Assignments Requested')
      expect(response.body).to include('Top 10 Abilities Requested')
    end
  end

  describe 'GET /organizations/:organization_id/insights/prompts' do
    before do
      allow_any_instance_of(OrganizationPolicy).to receive(:view_prompts?).and_return(true)
    end

    it 'returns http success' do
      get organization_insights_prompts_path(organization)
      expect(response).to have_http_status(:success)
    end

    it 'renders prompts insights page with timeframe links' do
      get organization_insights_prompts_path(organization)
      expect(response.body).to include('Insights: Prompts')
      expect(response.body).to include('Last 90 days')
      expect(response.body).to include('Last Year')
      expect(response.body).to include('All-Time')
    end

    it 'returns success with timeframe=year' do
      get organization_insights_prompts_path(organization, timeframe: 'year')
      expect(response).to have_http_status(:success)
    end

    it 'returns success with timeframe=all_time' do
      get organization_insights_prompts_path(organization, timeframe: 'all_time')
      expect(response).to have_http_status(:success)
    end

    it 'includes the answers chart container' do
      get organization_insights_prompts_path(organization)
      expect(response.body).to include('prompts-answers-by-template-chart')
    end

    it 'includes the teammates chart container' do
      get organization_insights_prompts_path(organization)
      expect(response.body).to include('prompts-teammates-by-template-chart')
    end

    it 'includes download button with access scope and teammate count' do
      get organization_insights_prompts_path(organization)
      expect(response.body).to include('I have access to')
      expect(response.body).to include('teammates.')
      expect(response.body).to include('prompts/download')
    end
  end

  describe 'GET /organizations/:organization_id/insights/prompts/download' do
    before do
      allow_any_instance_of(OrganizationPolicy).to receive(:view_prompts?).and_return(true)
    end

    it 'returns CSV with correct headers' do
      get organization_insights_prompts_download_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Teammate')
      expect(response.body).to include('Prompt template name')
      expect(response.body).to include('Date created')
    end
  end

  describe 'GET /organizations/:organization_id/insights/goals' do
    before do
      allow_any_instance_of(OrganizationPolicy).to receive(:view_goals?).and_return(true)
    end

    it 'returns http success' do
      get organization_insights_goals_path(organization)
      expect(response).to have_http_status(:success)
    end

    it 'renders goals insights page with timeframe links' do
      get organization_insights_goals_path(organization)
      expect(response.body).to include('Insights: Goals')
      expect(response.body).to include('Last 90 days')
      expect(response.body).to include('Last Year')
      expect(response.body).to include('All-Time')
    end

    it 'returns success with timeframe=year' do
      get organization_insights_goals_path(organization, timeframe: 'year')
      expect(response).to have_http_status(:success)
    end

    it 'returns success with timeframe=all_time' do
      get organization_insights_goals_path(organization, timeframe: 'all_time')
      expect(response).to have_http_status(:success)
    end

    it 'includes the goals by week chart container' do
      get organization_insights_goals_path(organization)
      expect(response.body).to include('goals-by-week-chart')
    end

    it 'includes the goals employees chart container' do
      get organization_insights_goals_path(organization)
      expect(response.body).to include('goals-employees-chart')
    end
  end
end
