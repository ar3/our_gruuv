# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::Insights values', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:viewer_person) { create(:person, first_name: 'Viewer', last_name: 'Person') }
  let!(:viewer_teammate) do
    create(
      :company_teammate,
      :assigned_employee,
      person: viewer_person,
      organization: organization,
      first_employed_at: 1.year.ago,
      last_terminated_at: nil
    )
  end

  let(:observer_person) { create(:person, first_name: 'Observer', last_name: 'Writer') }
  let!(:observer_teammate) do
    create(
      :company_teammate,
      :assigned_employee,
      person: observer_person,
      organization: organization,
      first_employed_at: 1.year.ago,
      last_terminated_at: nil
    )
  end

  let(:observee_person) { create(:person, first_name: 'Public', last_name: 'Observee') }
  let!(:observee_teammate) do
    create(
      :company_teammate,
      :assigned_employee,
      person: observee_person,
      organization: organization,
      first_employed_at: 1.year.ago,
      last_terminated_at: nil
    )
  end

  let(:private_person) { create(:person, first_name: 'Private', last_name: 'Only') }
  let!(:private_teammate) do
    create(
      :company_teammate,
      :assigned_employee,
      person: private_person,
      organization: organization,
      first_employed_at: 1.year.ago,
      last_terminated_at: nil
    )
  end

  let!(:aspiration) { create(:aspiration, company: organization, name: 'Integrity', sort_order: 1) }
  let!(:other_aspiration) { create(:aspiration, company: organization, name: 'Courage', sort_order: 2) }

  def publish_ogo!(privacy:, observee:, rate_aspiration:, observer: observer_person, published_at: Time.current, points: 0)
    observation = build(
      :observation,
      :published,
      company: organization,
      observer: observer,
      privacy_level: privacy,
      published_at: published_at
    )
    observation.observees.destroy_all
    observation.observees.build(teammate: observee)
    observation.save!
    create(:observation_rating, observation: observation, rateable: rate_aspiration, rating: :agree)
    if points.positive?
      create(
        :points_exchange_transaction,
        organization: organization,
        company_teammate: observee,
        observation: observation,
        points_to_spend_delta: points,
        points_to_give_delta: 0
      )
    end
    observation
  end

  before do
    sign_in_as_teammate_for_request(viewer_person, organization)
    allow_any_instance_of(OrganizationPolicy).to receive(:view_aspirations?).and_return(true)
    allow_any_instance_of(OrganizationPolicy).to receive(:view_observations?).and_return(true)
    allow_any_instance_of(OrganizationPolicy).to receive(:manage_employment?).and_return(false)
  end

  describe 'GET /organizations/:organization_id/insights (index hub)' do
    it 'includes a Values card when the viewer can view aspirations' do
      get organization_insights_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Values')
      expect(response.body).to include(organization_insights_values_path(organization))
    end
  end

  describe 'GET /organizations/:organization_id/insights/values' do
    it 'returns http success and renders page shell with timeframe' do
      get organization_insights_values_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Insights: Values')
      expect(response.body).to include('Last 90 days')
      expect(response.body).to include('Last Year')
      expect(response.body).to include('All-Time')
      expect(response.body).to include('Custom')
      expect(response.body).to include('Which values are we living?')
      expect(response.body).to include('Values champions')
      expect(response.body).not_to include('aria-label="Marker style"')
      expect(response.body).to include(organization_aspirations_path(organization))
    end

    it 'returns success for year and custom timeframes' do
      get organization_insights_values_path(organization, timeframe: 'year')
      expect(response).to have_http_status(:success)

      get organization_insights_values_path(
        organization,
        timeframe: 'custom',
        from: 30.days.ago.to_date.iso8601,
        to: Time.zone.today.iso8601
      )
      expect(response).to have_http_status(:success)
    end

    it 'shows living totals including private OGOs and ranks by volume' do
      publish_ogo!(privacy: :public_to_company, observee: observee_teammate, rate_aspiration: aspiration, points: 10)
      publish_ogo!(privacy: :public_to_company, observee: observee_teammate, rate_aspiration: aspiration, points: 5)
      publish_ogo!(privacy: :observed_and_managers, observee: private_teammate, rate_aspiration: aspiration)
      publish_ogo!(privacy: :public_to_company, observee: observee_teammate, rate_aspiration: other_aspiration)

      get organization_insights_values_path(organization, timeframe: 'all_time')

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Integrity')
      expect(response.body).to include('Courage')
      # Living table: Integrity has 3 total / 2 public / 1 private
      expect(response.body).to match(/Integrity[\s\S]*?>3</)
      expect(response.body).to match(/Integrity[\s\S]*?>2</)
      expect(response.body).to match(/Integrity[\s\S]*?>1</)
    end

    it 'lists public champions with OGO counts and points, excluding private-only people' do
      publish_ogo!(privacy: :public_to_company, observee: observee_teammate, rate_aspiration: aspiration, points: 10)
      publish_ogo!(privacy: :public_to_company, observee: observee_teammate, rate_aspiration: aspiration, points: 5)
      publish_ogo!(privacy: :observed_and_managers, observee: private_teammate, rate_aspiration: aspiration)

      get organization_insights_values_path(organization, timeframe: 'all_time')

      expect(response.body).to include(observee_person.display_name)
      expect(response.body).to include(observer_person.display_name)
      expect(response.body).not_to include(private_person.display_name)
      expect(response.body).to include('>15<').or include('>15.0<').or include('15')
    end

    it 'respects published_at timeframe for living and champions' do
      publish_ogo!(
        privacy: :public_to_company,
        observee: observee_teammate,
        rate_aspiration: aspiration,
        published_at: 2.years.ago,
        points: 20
      )
      publish_ogo!(
        privacy: :public_to_company,
        observee: observee_teammate,
        rate_aspiration: aspiration,
        published_at: 1.day.ago,
        points: 7
      )

      get organization_insights_values_path(organization, timeframe: '90_days')

      expect(response).to have_http_status(:success)
      expect(response.body).to include(observee_person.display_name)
      # Only the recent OGO counts in this timeframe
      expect(response.body).to match(/Integrity[\s\S]*?>1</)
    end
  end
end
