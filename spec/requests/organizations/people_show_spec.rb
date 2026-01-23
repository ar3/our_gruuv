require 'rails_helper'

RSpec.describe 'Organizations::People Show', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:person_teammate) { create(:company_teammate, person: person, organization: organization) }
  let(:manager) { create(:person) }
  let(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization) }

  before do
    # Create active employment for the person
    create(:employment_tenure, teammate: person_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    person_teammate.update!(first_employed_at: 1.year.ago)
    
    # Create active employment for manager
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 2.years.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 2.years.ago)
    
    # Set manager relationship
    person_teammate.employment_tenures.first.update!(manager_teammate: manager_teammate)
  end

  describe 'GET /organizations/:organization_id/people/:id' do
    context 'when user is authorized' do
      before do
        sign_in_as_teammate_for_request(manager, organization)
      end

      it 'returns success' do
        get organization_company_teammate_path(organization, person_teammate)
        expect(response).to have_http_status(:success)
      end

      it 'loads page visits data' do
        # Create some page visits
        create(:page_visit, person: person, url: '/organizations/1/people/1', page_title: 'Person Page', visit_count: 5, visited_at: 2.days.ago)
        create(:page_visit, person: person, url: '/organizations/1/people/2', page_title: 'Another Person', visit_count: 3, visited_at: 1.day.ago)
        create(:page_visit, person: person, url: '/organizations/1', page_title: 'Organization Page', visit_count: 10, visited_at: 3.days.ago)
        create(:page_visit, person: person, url: '/organizations/1/assignments', page_title: 'Assignments', visit_count: 2, visited_at: 5.days.ago)
        create(:page_visit, person: person, url: '/organizations/1/abilities', page_title: 'Abilities', visit_count: 1, visited_at: 1.hour.ago)

        get organization_company_teammate_path(organization, person_teammate)

        expect(assigns(:most_visited_pages)).to be_present
        expect(assigns(:most_visited_pages).count).to eq(5)
        expect(assigns(:most_visited_pages).first.visit_count).to eq(10) # Most visited should be first
        
        expect(assigns(:most_recent_pages)).to be_present
        expect(assigns(:most_recent_pages).count).to eq(5)
        expect(assigns(:most_recent_pages).first.visited_at).to be > assigns(:most_recent_pages).last.visited_at # Most recent should be first
      end

      it 'limits most visited pages to 5' do
        # Create more than 5 page visits
        7.times do |i|
          create(:page_visit, person: person, url: "/page#{i}", page_title: "Page #{i}", visit_count: i + 1, visited_at: i.days.ago)
        end

        get organization_company_teammate_path(organization, person_teammate)

        expect(assigns(:most_visited_pages).count).to eq(5)
      end

      it 'limits most recent pages to 5' do
        # Create more than 5 page visits
        7.times do |i|
          create(:page_visit, person: person, url: "/page#{i}", page_title: "Page #{i}", visit_count: 1, visited_at: i.hours.ago)
        end

        get organization_company_teammate_path(organization, person_teammate)

        expect(assigns(:most_recent_pages).count).to eq(5)
      end

      it 'handles person with no page visits' do
        get organization_company_teammate_path(organization, person_teammate)

        expect(assigns(:most_visited_pages)).to be_empty
        expect(assigns(:most_recent_pages)).to be_empty
        expect(response).to have_http_status(:success)
      end

      it 'renders the page visits section in the response' do
        create(:page_visit, person: person, url: '/test', page_title: 'Test Page', visit_count: 1, visited_at: 1.hour.ago)

        get organization_company_teammate_path(organization, person_teammate)

        expect(response.body).to include('Page Visits')
        expect(response.body).to include('Top 5 Most Visited Pages')
        expect(response.body).to include('Top 5 Most Recent Pages')
      end
    end

    context 'when user is the person themselves' do
      before do
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'returns success' do
        get organization_company_teammate_path(organization, person_teammate)
        expect(response).to have_http_status(:success)
      end

      it 'loads their own page visits' do
        create(:page_visit, person: person, url: '/my-page', page_title: 'My Page', visit_count: 1, visited_at: 1.hour.ago)

        get organization_company_teammate_path(organization, person_teammate)

        expect(assigns(:most_visited_pages)).to be_present
        expect(assigns(:most_visited_pages).first.person).to eq(person)
      end

      context 'Asana identity management' do
        it 'shows Connect Asana Account button when no Asana identity exists' do
          get organization_company_teammate_path(organization, person_teammate)

          expect(response).to have_http_status(:success)
          expect(response.body).to include('Connect Asana Account')
          expect(response.body).not_to include('Disconnect Asana Account')
        end

        it 'shows Disconnect Asana Account button when Asana identity exists' do
          create(:teammate_identity, :asana, teammate: person_teammate)

          get organization_company_teammate_path(organization, person_teammate)

          expect(response).to have_http_status(:success)
          expect(response.body).to include('Disconnect Asana Account')
          expect(response.body).not_to include('Connect Asana Account')
        end

        it 'disconnects Asana account when disconnect button is clicked' do
          asana_identity = create(:teammate_identity, :asana, teammate: person_teammate)

          expect {
            delete organization_company_teammate_asana_disconnect_path(organization, person_teammate)
          }.to change(TeammateIdentity, :count).by(-1)

          expect(response).to redirect_to(organization_company_teammate_path(organization, person_teammate))
          expect(flash[:notice]).to include('Asana account disconnected successfully')
          expect(person_teammate.reload.asana_identity).to be_nil
        end

        it 'handles disconnect when no Asana identity exists' do
          delete organization_company_teammate_asana_disconnect_path(organization, person_teammate)

          expect(response).to redirect_to(organization_company_teammate_path(organization, person_teammate))
          expect(flash[:alert]).to include('No Asana account connected')
        end
      end
    end

    context 'when user is not authorized' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:teammate, person: other_person, organization: organization) }

      before do
        create(:employment_tenure, teammate: other_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        other_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(other_person, organization)
      end

      it 'redirects with authorization error' do
        get organization_company_teammate_path(organization, person_teammate)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is unauthenticated' do
      it 'redirects to login' do
        get organization_company_teammate_path(organization, person_teammate)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end

