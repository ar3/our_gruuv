require 'rails_helper'

RSpec.describe 'Teammate View Security', type: :request do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:person_teammate) { create(:teammate, person: person, organization: organization) }

  before do
    # Create active employment for the person
    create(:employment_tenure, teammate: person_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    person_teammate.update!(first_employed_at: 1.year.ago)
  end

  describe 'GET /organizations/:organization_id/company_teammates/:id/internal' do
    context 'when user is an active teammate in same organization' do
      let(:viewer) { create(:person) }
      let(:viewer_teammate) { create(:teammate, person: viewer, organization: organization) }

      before do
        create(:employment_tenure, teammate: viewer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        viewer_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(viewer, organization)
      end

      it 'allows access' do
        get internal_organization_company_teammate_path(organization, person_teammate)
        expect(response).to have_http_status(:success)
      end

      it 'renders the teammate views navigation (manager-lite rows, 1:1 hub first, public link when present)' do
        get internal_organization_company_teammate_path(organization, person_teammate)
        expect(response.body).to include("Views for #{person.casual_name}")
        expect(response.body).to include('internal-teammate-views-nav')
        expect(response.body).to include('next most important thing')
        expect(response.body).to include('1:1, about &amp; growth')
        expect(response.body).to include('Clarity check-ins')
        expect(response.body).to include('Public view')
        expect(response.body).to include(public_person_path(person))
        expect(response.body).to include('internal-teammate-views-nav__expand-prompt')
        expect(response.body).to include('views and actions you can take for')
        expect(response.body).to include('OGOs, Goals, Grow by')
        expect(response.body).to include('Grow by experiences')
        expect(response.body).to include('Grow by Abilities')
        expect(response.body).to include('Position / Title Change')
      end

      it 'includes link to observation index filtered by observations about the teammate' do
        get internal_organization_company_teammate_path(organization, person_teammate)
        expect(response).to have_http_status(:success)
        observations_about_path = organization_observations_path(organization, observee_ids: [person_teammate.id])
        expect(response.body).to include(observations_about_path)
        expect(response.body).to include('OGOs Received')
        expect(response.body).to include('bi-link-45deg')
      end

      it 'includes link to observation index filtered by observations by the teammate' do
        get internal_organization_company_teammate_path(organization, person_teammate)
        expect(response).to have_http_status(:success)
        observations_by_path = organization_observations_path(organization, observer_id: person.id)
        expect(response.body).to include(observations_by_path)
        expect(response.body).to include('OGOs Given')
      end

      context 'with active assignment tenures' do
        let!(:assignment) { create(:assignment, company: organization, title: 'Ship the feature') }

        before do
          create(:assignment_tenure, teammate: person_teammate, assignment: assignment, started_at: 1.week.ago, ended_at: nil, anticipated_energy_percentage: 40)
        end

        it 'links to add an observation about the teammate taking on each assignment' do
          get internal_organization_company_teammate_path(organization, person_teammate)
          expect(response).to have_http_status(:success)
          expect(response.body).to include("New OGO about #{person.casual_name}")
          expect(response.body).to include("and #{assignment.title}")

          doc = Nokogiri::HTML(response.body)
          add_link = doc.at_xpath("//a[contains(., 'New OGO about')]")
          expect(add_link).to be_present

          href = add_link['href']
          uri = URI.parse(href)
          params = Rack::Utils.parse_nested_query(uri.query)
          expect(uri.path).to eq(new_organization_observation_path(organization))
          expect(params['observee_ids']).to eq([person_teammate.id.to_s])
          expect(params['rateable_type']).to eq('Assignment')
          expect(params['rateable_id']).to eq(assignment.id.to_s)
          expect(params['return_text']).to eq("Back to #{person.casual_name}'s assignments")
          expect(params['return_url']).to include('#assignments')
        end
      end
    end

    context 'when user is unauthenticated' do
      it 'raises error (unauthenticated access not supported)' do
        # Don't sign in - test unauthenticated access
        # The controller redirects unauthenticated users
        get internal_organization_company_teammate_path(organization, person_teammate)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is active teammate from different organization' do
      let(:viewer) { create(:person) }
      let(:viewer_teammate) { create(:teammate, person: viewer, organization: other_organization) }

      before do
        create(:employment_tenure, teammate: viewer_teammate, company: other_organization, started_at: 1.year.ago, ended_at: nil)
        viewer_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(viewer, other_organization)
      end

      it 'denies access' do
        get internal_organization_company_teammate_path(organization, person_teammate)
        expect(response).to have_http_status(:redirect)
        # User from different organization is redirected by ensure_teammate_matches_organization
        # May redirect to organizations_path or dashboard depending on implementation
        expect(response.redirect_url).to include('/organizations')
      end
    end

    context 'when user is inactive teammate (no active employment)' do
      let(:viewer) { create(:person) }
      let(:viewer_teammate) { create(:teammate, person: viewer, organization: organization) }

      before do
        # Create past employment (ended)
        create(:employment_tenure, teammate: viewer_teammate, company: organization, started_at: 2.years.ago, ended_at: 1.year.ago)
        viewer_teammate.update!(first_employed_at: 2.years.ago, last_terminated_at: 1.year.ago)
        sign_in_as_teammate_for_request(viewer, organization)
      end

      it 'denies access (inactive viewers cannot view others)' do
        get internal_organization_company_teammate_path(organization, person_teammate)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when person has no employment in organization' do
      let(:person_without_employment) { create(:person) }
      let(:person_without_employment_teammate) { create(:teammate, person: person_without_employment, organization: organization) }
      let(:viewer) { create(:person) }
      let(:viewer_teammate) { create(:teammate, person: viewer, organization: organization) }

      before do
        # Person has teammate but no employment
        person_without_employment_teammate
        create(:employment_tenure, teammate: viewer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        viewer_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(viewer, organization)
      end

      it 'allows access (teammate record exists, even without employment)' do
        get internal_organization_company_teammate_path(organization, person_without_employment_teammate)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when person has only inactive employment tenures' do
      let(:person_with_inactive_employment) { create(:person) }
      let(:person_with_inactive_employment_teammate) { create(:teammate, person: person_with_inactive_employment, organization: organization) }
      let(:viewer) { create(:person) }
      let(:viewer_teammate) { create(:teammate, person: viewer, organization: organization) }

      before do
        # Person has teammate with only ended employment
        create(:employment_tenure, teammate: person_with_inactive_employment_teammate, company: organization, started_at: 2.years.ago, ended_at: 1.year.ago)
        person_with_inactive_employment_teammate.update!(first_employed_at: 2.years.ago, last_terminated_at: 1.year.ago)
        create(:employment_tenure, teammate: viewer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        viewer_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(viewer, organization)
      end

      it 'allows access (teammate record exists, even with only inactive employment)' do
        get internal_organization_company_teammate_path(organization, person_with_inactive_employment_teammate)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when viewing own record as inactive teammate' do
      let(:inactive_person) { create(:person) }
      let(:inactive_person_teammate) { create(:teammate, person: inactive_person, organization: organization) }

      before do
        # Create past employment (ended)
        create(:employment_tenure, teammate: inactive_person_teammate, company: organization, started_at: 2.years.ago, ended_at: 1.year.ago)
        inactive_person_teammate.update!(first_employed_at: 2.years.ago, last_terminated_at: 1.year.ago)
        sign_in_as_teammate_for_request(inactive_person, organization)
      end

      it 'allows access (can always view own record)' do
        get internal_organization_company_teammate_path(organization, inactive_person_teammate)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when viewing own record with no employment' do
      let(:own_person_without_employment) { create(:person) }
      let(:own_person_without_employment_teammate) do
        # Find or create to avoid duplicate person issues
        own_person_without_employment.company_teammates.find_or_create_by!(organization: organization) { |t| t.first_employed_at = nil; t.last_terminated_at = nil }
      end

      before do
        # Person has teammate but no employment
        own_person_without_employment_teammate # Ensure it's created
        sign_in_as_teammate_for_request(own_person_without_employment, organization)
      end

      it 'allows access (can always view own record)' do
        get internal_organization_company_teammate_path(organization, own_person_without_employment_teammate)
        expect(response).to have_http_status(:success)
      end
    end
  end
end

