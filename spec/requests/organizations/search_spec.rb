require 'rails_helper'

RSpec.describe 'Organizations::Search', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }

  before do
    # Create active employment for the teammate
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
  end

  describe 'GET /organizations/:organization_id/search' do
    context 'when user is authenticated and authorized' do
      before do
        sign_in_as_teammate_for_request(person, organization)
      end

      context 'without search query' do
        it 'returns success' do
          get organization_search_path(organization)
          expect(response).to have_http_status(:success)
        end

        it 'assigns empty query' do
          get organization_search_path(organization)
          expect(assigns(:query)).to eq('')
        end

        it 'assigns empty results' do
          get organization_search_path(organization)
          expect(assigns(:results)).to be_present
          expect(assigns(:results)[:total_count]).to eq(0)
          expect(assigns(:results)[:people]).to be_empty
          expect(assigns(:results)[:organizations]).to be_empty
          expect(assigns(:results)[:observations]).to be_empty
          expect(assigns(:results)[:assignments]).to be_empty
          expect(assigns(:results)[:abilities]).to be_empty
        end

        it 'renders the show template' do
          get organization_search_path(organization)
          expect(response).to render_template(:show)
        end

        it 'assigns the organization' do
          get organization_search_path(organization)
          expect(assigns(:organization).id).to eq(organization.id)
        end
      end

      context 'with search query' do
        it 'returns success' do
          get organization_search_path(organization, q: 'test')
          expect(response).to have_http_status(:success)
        end

        it 'assigns the query parameter' do
          get organization_search_path(organization, q: 'test query')
          expect(assigns(:query)).to eq('test query')
        end

        it 'strips whitespace from query' do
          get organization_search_path(organization, q: '  test query  ')
          expect(assigns(:query)).to eq('test query')
        end

        it 'assigns search results' do
          get organization_search_path(organization, q: 'test')
          expect(assigns(:results)).to be_present
          expect(assigns(:results)).to have_key(:people)
          expect(assigns(:results)).to have_key(:organizations)
          expect(assigns(:results)).to have_key(:observations)
          expect(assigns(:results)).to have_key(:assignments)
          expect(assigns(:results)).to have_key(:abilities)
          expect(assigns(:results)).to have_key(:total_count)
        end

        it 'renders the show template' do
          get organization_search_path(organization, q: 'test')
          expect(response).to render_template(:show)
        end

        it 'assigns the organization' do
          get organization_search_path(organization, q: 'test')
          expect(assigns(:organization).id).to eq(organization.id)
        end
      end

      context 'with empty query parameter' do
        it 'treats empty string as no query' do
          get organization_search_path(organization, q: '')
          expect(assigns(:query)).to eq('')
          expect(assigns(:results)[:total_count]).to eq(0)
        end
      end

      context 'with people in search results' do
        let(:searchable_person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john.doe@example.com') }
        let(:searchable_teammate) { create(:teammate, person: searchable_person, organization: organization, type: 'CompanyTeammate') }

        before do
          # Create active employment for the searchable person
          create(:employment_tenure, teammate: searchable_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
          searchable_teammate.update!(first_employed_at: 1.year.ago)
          
          # Index the person for search
          PgSearch::Multisearch.rebuild(Person)
        end

        it 'renders people results with correct links' do
          get organization_search_path(organization, q: 'John')
          expect(response).to have_http_status(:success)
          expect(response.body).to include('John Doe')
          expect(response.body).to include('john.doe@example.com')
          # Should link to internal teammate view
          expect(response.body).to include(internal_organization_company_teammate_path(organization, searchable_teammate))
          # Should not have the error about undefined method
          expect(response.body).not_to include('teammate_organization_company_teammate_path')
        end

        it 'finds CompanyTeammate for people in results' do
          get organization_search_path(organization, q: 'John')
          expect(assigns(:results)[:people]).to include(searchable_person)
          # Verify the person has a teammate in the organization
          found_teammate = searchable_person.teammates.find_by(organization: organization, type: 'CompanyTeammate')
          expect(found_teammate.id).to eq(searchable_teammate.id)
          expect(found_teammate).to be_a(CompanyTeammate)
        end
      end
    end

    context 'when user is unauthenticated' do
      it 'redirects to login' do
        get organization_search_path(organization)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is authenticated but not a teammate' do
      let(:other_person) { create(:person) }
      let(:other_organization) { create(:organization, :company) }
      let(:other_teammate) { create(:teammate, person: other_person, organization: other_organization) }

      before do
        create(:employment_tenure, teammate: other_teammate, company: other_organization, started_at: 1.year.ago, ended_at: nil)
        other_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(other_person, other_organization)
      end

      it 'redirects with authorization error' do
        get organization_search_path(organization)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organizations_path)
      end
    end
  end
end

