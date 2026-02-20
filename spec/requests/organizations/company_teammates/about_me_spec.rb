require 'rails_helper'

RSpec.describe 'About Me Page', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/company_teammates/:id/about_me' do
    context 'when user has view_check_ins permission' do
      it 'allows access' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response).to have_http_status(:success)
      end

      it 'renders the about_me template' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response).to render_template(:about_me)
      end

      it 'uses determine_layout method for layout' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response).to have_http_status(:success)
        # Layout is determined by determine_layout method, not hardcoded
      end

      it 'loads all necessary data' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(assigns(:teammate)).to be_a(CompanyTeammate)
        expect(assigns(:teammate).id).to eq(teammate.id)
        expect(assigns(:person)).to eq(person)
      end

      it 'assigns observations_involving_url for the teammate' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(assigns(:observations_involving_url)).to be_present
        expect(assigns(:observations_involving_url)).to include("involving_teammate_id=#{teammate.id}")
      end
    end

    context 'when user does not have view_check_ins permission' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:company_teammate, person: other_person, organization: organization) }

      before do
        create(:employment_tenure, teammate: other_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        other_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(other_person, organization)
      end

      it 'denies access when viewing another teammate without permission' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when user is unauthenticated' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(nil)
      end

      it 'redirects to root path' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'Navigation link' do
    it 'appears in navigation for authorized users' do
      get dashboard_organization_path(organization)
      follow_redirect!
      expect(response.body).to include('About')
      expect(response.body).to include(person.casual_name)
    end
  end

  describe 'View switcher' do
    it 'includes About Me View option' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('About Me View')
    end

    it 'shows About Me View as active when on about_me page' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('About Me View (Active)')
    end
  end

  describe 'Page title and header' do
    it 'uses title and header "About <casual name>"' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include("<title>About #{person.casual_name}</title>")
      expect(response.body).to include("About #{person.casual_name}")
    end
  end

  describe 'Sections rendering' do
    it 'renders stories section' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('stories')
    end

    it 'renders goals section' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to match(/Active Goals/i)
    end

    it 'links Manage Goals & Confidence Ratings to goals index with owner and hierarchical-collapsible view' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Manage Goals")
      expect(response.body).to include("CompanyTeammate_#{teammate.id}")
      expect(response.body).to include("view=hierarchical-collapsible")
    end

    it 'renders prompts section when company has active prompts' do
      create(:prompt_template, company: organization, available_at: 1.day.ago)
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to match(/Prompts.*Reflections/i)
    end

    it 'hides prompts section when company has no active prompts' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).not_to match(/Prompts.*Reflections/i)
    end

    it 'renders 1:1 area section' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('1:1 Area')
    end

    it 'renders position check-in section' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to match(/Position\/Overall/i)
    end

    it 'renders assignments check-in section' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to match(/Assignments\/Outcomes/i)
    end

    context 'assignment check-in data loading' do
      let(:title) { create(:title, company: organization) }
      let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
      let(:position) { create(:position, title: title, position_level: position_level) }

      before do
        # End the existing employment_tenure from the main before block and create a new one with position
        EmploymentTenure.where(company_teammate: teammate, company: organization, ended_at: nil).update_all(ended_at: 2.years.ago)
        create(:employment_tenure, teammate: teammate, company: organization, position: position, started_at: 1.year.ago, ended_at: nil)
        teammate.reload
      end

      context 'when position has required assignments' do
        let(:required_assignment) { create(:assignment, company: organization) }

        before do
          # Get the actual position from the employment tenure
          company_teammate = CompanyTeammate.find(teammate.id)
          actual_position = company_teammate.active_employment_tenure.position
          create(:position_assignment, position: actual_position, assignment: required_assignment, assignment_type: 'required')
        end

        it 'loads required assignments' do
          get about_me_organization_company_teammate_path(organization, teammate)
          expect(assigns(:required_assignments)).to include(required_assignment)
          expect(assigns(:assignment_check_ins_data).map { |d| d[:assignment] }).to include(required_assignment)
        end

        it 'includes position_assignment in data' do
          get about_me_organization_company_teammate_path(organization, teammate)
          data = assigns(:assignment_check_ins_data).find { |d| d[:assignment] == required_assignment }
          expect(data[:position_assignment]).to be_present
          expect(data[:position_assignment].assignment).to eq(required_assignment)
        end
      end

      context 'when teammate has active assignments with energy > 0' do
        let(:active_assignment) { create(:assignment, company: organization) }
        let!(:assignment_tenure) { create(:assignment_tenure, teammate: teammate, assignment: active_assignment, anticipated_energy_percentage: 50, started_at: 1.month.ago, ended_at: nil) }

        it 'loads active assignments with energy > 0' do
          get about_me_organization_company_teammate_path(organization, teammate)
          expect(assigns(:required_assignments)).to include(active_assignment)
          expect(assigns(:assignment_check_ins_data).map { |d| d[:assignment] }).to include(active_assignment)
        end

        it 'includes assignment_tenure in data' do
          get about_me_organization_company_teammate_path(organization, teammate)
          data = assigns(:assignment_check_ins_data).find { |d| d[:assignment] == active_assignment }
          expect(data[:assignment_tenure]).to be_present
          expect(data[:assignment_tenure].assignment).to eq(active_assignment)
        end
      end

      context 'when teammate has both required and active assignments' do
        let(:required_assignment) { create(:assignment, company: organization) }
        let(:active_assignment) { create(:assignment, company: organization) }

        before do
          # Get the actual position from the employment tenure
          company_teammate = CompanyTeammate.find(teammate.id)
          actual_position = company_teammate.active_employment_tenure.position
          create(:position_assignment, position: actual_position, assignment: required_assignment, assignment_type: 'required')
          create(:assignment_tenure, teammate: teammate, assignment: active_assignment, anticipated_energy_percentage: 50, started_at: 1.month.ago, ended_at: nil)
        end

        it 'loads both types of assignments' do
          get about_me_organization_company_teammate_path(organization, teammate)
          expect(assigns(:required_assignments)).to include(required_assignment, active_assignment)
          expect(assigns(:assignment_check_ins_data).map { |d| d[:assignment] }).to include(required_assignment, active_assignment)
        end
      end

      context 'when assignment is both required and active with energy > 0' do
        let(:shared_assignment) { create(:assignment, company: organization) }

        before do
          # Get the actual position from the employment tenure
          company_teammate = CompanyTeammate.find(teammate.id)
          actual_position = company_teammate.active_employment_tenure.position
          create(:position_assignment, position: actual_position, assignment: shared_assignment, assignment_type: 'required')
          create(:assignment_tenure, teammate: teammate, assignment: shared_assignment, anticipated_energy_percentage: 50, started_at: 1.month.ago, ended_at: nil)
        end

        it 'includes the assignment only once' do
          get about_me_organization_company_teammate_path(organization, teammate)
          expect(assigns(:required_assignments).count).to eq(1)
          expect(assigns(:assignment_check_ins_data).count).to eq(1)
          expect(assigns(:assignment_check_ins_data).first[:assignment]).to eq(shared_assignment)
        end

        it 'includes both position_assignment and assignment_tenure in data' do
          get about_me_organization_company_teammate_path(organization, teammate)
          data = assigns(:assignment_check_ins_data).first
          expect(data[:position_assignment]).to be_present
          expect(data[:position_assignment].assignment).to eq(shared_assignment)
          expect(data[:assignment_tenure]).to be_present
          expect(data[:assignment_tenure].assignment).to eq(shared_assignment)
        end
      end

      context 'when active assignment has energy = 0' do
        let(:assignment) { create(:assignment, company: organization) }
        let!(:assignment_tenure) { create(:assignment_tenure, teammate: teammate, assignment: assignment, anticipated_energy_percentage: 0, started_at: 1.month.ago, ended_at: nil) }

        it 'does not include it' do
          get about_me_organization_company_teammate_path(organization, teammate)
          expect(assigns(:required_assignments)).not_to include(assignment)
          expect(assigns(:assignment_check_ins_data).map { |d| d[:assignment] }).not_to include(assignment)
        end
      end

      context 'when counting assignments with recent check-ins' do
        let(:assignment1) { create(:assignment, company: organization) }
        let(:assignment2) { create(:assignment, company: organization) }
        let(:finalized_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }
        let(:manager_completed_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }

        before do
          # Get the actual position from the employment tenure
          company_teammate = CompanyTeammate.find(teammate.id)
          actual_position = company_teammate.active_employment_tenure.position
          create(:position_assignment, position: actual_position, assignment: assignment1, assignment_type: 'required')
          create(:position_assignment, position: actual_position, assignment: assignment2, assignment_type: 'required')
          
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: assignment1,
                 employee_completed_at: 30.days.ago,
                 manager_completed_at: 30.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 30.days.ago,
                 finalized_by_teammate: finalized_by)
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: assignment2,
                 employee_completed_at: 100.days.ago,
                 manager_completed_at: 100.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 100.days.ago,
                 finalized_by_teammate: finalized_by)
        end

        it 'counts only assignments with check-ins in last 90 days' do
          get about_me_organization_company_teammate_path(organization, teammate)
          expect(assigns(:assignments_with_recent_check_ins_count)).to eq(1)
        end
      end
    end

    it 'renders aspirations check-in section' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to match(/Aspirational Values/i)
    end

    it 'renders abilities section' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('Abilities')
    end
  end

  describe 'Observations section' do
    let(:other_person) { create(:person) }
    let(:other_teammate) { create(:company_teammate, person: other_person, organization: organization) }
    let(:third_person) { create(:person) }
    let(:third_teammate) { create(:company_teammate, person: third_person, organization: organization) }

    it 'shows View All observations involving link with teammate casual name' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include("View All observations involving #{person.casual_name}")
      expect(response.body).to include("involving_teammate_id=#{teammate.id}")
    end

    context 'when teammate is only observer' do
      let!(:observation_given) do
        build(:observation,
              observer: person,
              company: organization,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago,
              published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end
      end

      it 'appears in Observations Given' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(assigns(:observations_given_count)).to eq(1)
        expect(assigns(:recent_observations_given)).to include(observation_given)
      end

      it 'does not appear in Observations Received' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(assigns(:observations_received_count)).to eq(0)
        expect(assigns(:recent_observations_received)).not_to include(observation_given)
      end
    end

    context 'when teammate is only observee' do
      let!(:observation_received) do
        build(:observation,
              observer: other_person,
              company: organization,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago,
              published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end
      end

      it 'appears in Observations Received' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(assigns(:observations_received_count)).to eq(1)
        expect(assigns(:recent_observations_received)).to include(observation_received)
      end

      it 'does not appear in Observations Given' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(assigns(:observations_given_count)).to eq(0)
        expect(assigns(:recent_observations_given)).not_to include(observation_received)
      end
    end

    context 'when teammate is both observer and observee (self-observation)' do
      let!(:self_observation) do
        build(:observation,
              observer: person,
              company: organization,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago,
              published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end
      end

      it 'does NOT appear in Observations Given' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(assigns(:observations_given_count)).to eq(0)
        expect(assigns(:recent_observations_given)).not_to include(self_observation)
      end

      it 'DOES appear in Observations Received' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(assigns(:observations_received_count)).to eq(1)
        expect(assigns(:recent_observations_received)).to include(self_observation)
      end

      it 'shows yellow indicator (0 given, 1 received)' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to match(/text-warning|bg-warning|alert-warning/)
      end
    end

    context 'when teammate is observer and one of multiple observees' do
      let!(:multi_observee_observation) do
        build(:observation,
              observer: person,
              company: organization,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago,
              published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end
      end

      it 'does NOT appear in Observations Given' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(assigns(:observations_given_count)).to eq(0)
        expect(assigns(:recent_observations_given)).not_to include(multi_observee_observation)
      end

      it 'DOES appear in Observations Received' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(assigns(:observations_received_count)).to eq(1)
        expect(assigns(:recent_observations_received)).to include(multi_observee_observation)
      end
    end

    context 'with mixed observations' do
      let!(:observation_given) do
        build(:observation,
              observer: person,
              company: organization,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago,
              published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end
      end

      let!(:observation_received) do
        build(:observation,
              observer: other_person,
              company: organization,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago,
              published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end
      end

      let!(:self_observation) do
        build(:observation,
              observer: person,
              company: organization,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago,
              published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end
      end

      it 'correctly separates observations into given and received' do
        get about_me_organization_company_teammate_path(organization, teammate)
        
        # Observations Given should only include observation_given (not self_observation)
        expect(assigns(:observations_given_count)).to eq(1)
        expect(assigns(:recent_observations_given)).to include(observation_given)
        expect(assigns(:recent_observations_given)).not_to include(self_observation)
        
        # Observations Received should include both observation_received and self_observation
        expect(assigns(:observations_received_count)).to eq(2)
        expect(assigns(:recent_observations_received)).to include(observation_received, self_observation)
        expect(assigns(:recent_observations_received)).not_to include(observation_given)
      end
    end

    context 'filtering' do
      it 'excludes observations older than 30 days' do
        recent = create(:observation,
                        observer: person,
                        company: organization,
                        privacy_level: :public_to_company,
                        observed_at: 10.days.ago,
                        published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        old = create(:observation,
                     observer: person,
                     company: organization,
                     privacy_level: :public_to_company,
                     observed_at: 35.days.ago,
                     published_at: 35.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        get about_me_organization_company_teammate_path(organization, teammate)
        expect(assigns(:observations_given_count)).to eq(1)
        expect(assigns(:recent_observations_given)).to include(recent)
        expect(assigns(:recent_observations_given)).not_to include(old)
      end

      it 'excludes draft observations' do
        published = create(:observation,
                           observer: person,
                           company: organization,
                           privacy_level: :public_to_company,
                           observed_at: 10.days.ago,
                           published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        draft = create(:observation,
                       observer: person,
                       company: organization,
                       privacy_level: :public_to_company,
                       observed_at: 10.days.ago,
                       published_at: nil).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        get about_me_organization_company_teammate_path(organization, teammate)
        expect(assigns(:observations_given_count)).to eq(1)
        expect(assigns(:recent_observations_given)).to include(published)
        expect(assigns(:recent_observations_given)).not_to include(draft)
      end

      it 'excludes observer_only privacy level' do
        observer_only = create(:observation,
                                observer: person,
                                company: organization,
                                privacy_level: :observer_only,
                                observed_at: 10.days.ago,
                                published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        public_obs = create(:observation,
                            observer: person,
                            company: organization,
                            privacy_level: :public_to_company,
                            observed_at: 10.days.ago,
                            published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        get about_me_organization_company_teammate_path(organization, teammate)
        expect(assigns(:observations_given_count)).to eq(1)
        expect(assigns(:recent_observations_given)).to include(public_obs)
        expect(assigns(:recent_observations_given)).not_to include(observer_only)
      end

      it 'excludes soft-deleted observations' do
        active = create(:observation,
                        observer: person,
                        company: organization,
                        privacy_level: :public_to_company,
                        observed_at: 10.days.ago,
                        published_at: 10.days.ago,
                        deleted_at: nil).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        deleted = create(:observation,
                         observer: person,
                         company: organization,
                         privacy_level: :public_to_company,
                         observed_at: 10.days.ago,
                         published_at: 10.days.ago,
                         deleted_at: 1.day.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        get about_me_organization_company_teammate_path(organization, teammate)
        expect(assigns(:observations_given_count)).to eq(1)
        expect(assigns(:recent_observations_given)).to include(active)
        expect(assigns(:recent_observations_given)).not_to include(deleted)
      end
    end
  end

  describe 'Status indicators' do
    context 'stories section' do
      it 'shows red indicator when no shareable observations in last 30 days' do
        get about_me_organization_company_teammate_path(organization, teammate)
        # Should show red indicator when 0 given and 0 received
        expect(response.body).to match(/text-danger|bg-danger|alert-danger/)
      end

      it 'shows green indicator when 1+ given and 1+ received' do
        other_person = create(:person)
        other_teammate = create(:company_teammate, person: other_person, organization: organization)
        
        observation_given = build(:observation,
                                 observer: person,
                                 company: organization,
                                 privacy_level: :public_to_company,
                                 observed_at: 10.days.ago,
                                 published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        observation_received = build(:observation,
                                    observer: other_person,
                                    company: organization,
                                    privacy_level: :public_to_company,
                                    observed_at: 10.days.ago,
                                    published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end

        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to match(/text-success|bg-success|alert-success/)
      end

      it 'shows green indicator when 2+ observations given' do
        other_person = create(:person)
        other_teammate = create(:company_teammate, person: other_person, organization: organization)
        
        observation_given1 = build(:observation,
                                  observer: person,
                                  company: organization,
                                  privacy_level: :public_to_company,
                                  observed_at: 10.days.ago,
                                  published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        observation_given2 = build(:observation,
                                   observer: person,
                                   company: organization,
                                   privacy_level: :public_to_company,
                                   observed_at: 10.days.ago,
                                   published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to match(/text-success|bg-success|alert-success/)
      end

      it 'shows yellow indicator when 1 observation given and 0 received' do
        other_person = create(:person)
        other_teammate = create(:company_teammate, person: other_person, organization: organization)
        
        observation_given = build(:observation,
                                 observer: person,
                                 company: organization,
                                 privacy_level: :public_to_company,
                                 observed_at: 10.days.ago,
                                 published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to match(/text-warning|bg-warning|alert-warning/)
      end

      it 'shows yellow indicator when 0 given but some received' do
        other_person = create(:person)
        other_teammate = create(:company_teammate, person: other_person, organization: organization)
        
        observation_received = build(:observation,
                                    observer: other_person,
                                    company: organization,
                                    privacy_level: :public_to_company,
                                    observed_at: 10.days.ago,
                                    published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end

        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to match(/text-warning|bg-warning|alert-warning/)
      end

      it 'shows collapsed text with given and received counts' do
        other_person = create(:person)
        other_teammate = create(:company_teammate, person: other_person, organization: organization)
        
        observation_given = build(:observation,
                                 observer: person,
                                 company: organization,
                                 privacy_level: :public_to_company,
                                 observed_at: 10.days.ago,
                                 published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        observation_received = build(:observation,
                                    observer: other_person,
                                    company: organization,
                                    privacy_level: :public_to_company,
                                    observed_at: 10.days.ago,
                                    published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end

        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include("#{person.casual_name} has given")
        expect(response.body).to include("observation")
        expect(response.body).to include("has received")
        expect(response.body).to include("in the past 30 days")
      end
    end

    context 'goals section' do
      it 'shows red indicator when no active goals' do
        get about_me_organization_company_teammate_path(organization, teammate)
        # Should show red indicator when no active goals
        expect(response.body).to match(/text-danger|bg-danger|alert-danger/)
      end

      it 'shows collapsed text with active goals, check-ins, and completed counts' do
        goal = create(:goal,
                     owner: teammate,
                     creator: teammate,
                     company: organization,
                     started_at: 1.day.ago,
                     completed_at: nil,
                     deleted_at: nil)

        cutoff_week = (Date.current - 14.days).beginning_of_week(:monday)
        confidence_reporter = create(:person)
        create(:goal_check_in,
               goal: goal,
               check_in_week_start: cutoff_week,
               confidence_reporter: confidence_reporter)

        completed_goal = create(:goal,
                               owner: teammate,
                               creator: teammate,
                               company: organization,
                               started_at: 60.days.ago,
                               completed_at: 30.days.ago,
                               deleted_at: nil)

        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include("#{person.casual_name} has")
        expect(response.body).to include("active goal")
        expect(response.body).to include("with a check-in in the past two weeks")
        expect(response.body).to include("completed in the last 90 days")
      end

      it 'shows draft goals button when draft goals exist' do
        draft_goal1 = create(:goal,
                           owner: teammate,
                           creator: teammate,
                           company: organization,
                           started_at: nil,
                           deleted_at: nil)
        draft_goal2 = create(:goal,
                           owner: teammate,
                           creator: teammate,
                           company: organization,
                           started_at: nil,
                           deleted_at: nil)

        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to match(/start or archive/i)
        expect(response.body).to include("2 draft goals")
        # Check for URL components
        expect(response.body).to include("owner_type=CompanyTeammate")
        expect(response.body).to include("owner_id=#{teammate.id}")
        expect(response.body).to include("status=draft")
      end

      it 'does not show draft goals button when no draft goals exist' do
        active_goal = create(:goal,
                           owner: teammate,
                           creator: teammate,
                           company: organization,
                           started_at: 1.day.ago,
                           deleted_at: nil)

        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).not_to include("start or archive")
        expect(response.body).not_to include("draft goal")
      end

      it 'does not count deleted draft goals' do
        draft_goal = create(:goal,
                           owner: teammate,
                           creator: teammate,
                           company: organization,
                           started_at: nil,
                           deleted_at: 1.day.ago)
        active_draft_goal = create(:goal,
                                 owner: teammate,
                                 creator: teammate,
                                 company: organization,
                                 started_at: nil,
                                 deleted_at: nil)

        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include("1 draft goal")
        expect(response.body).not_to include("2 draft goals")
      end

      it 'shows active goals without target dates' do
        # Goal without most_likely_target_date should still appear
        goal_without_date = create(:goal,
                                  owner: teammate,
                                  creator: teammate,
                                  company: organization,
                                  started_at: 1.day.ago,
                                  most_likely_target_date: nil,
                                  completed_at: nil,
                                  deleted_at: nil)

        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include(goal_without_date.title)
        expect(response.body).to include("#{person.casual_name} has")
        expect(response.body).to include("active goal")
      end

      it 'shows active goals with past target dates' do
        # Goal with past most_likely_target_date should still appear
        goal_with_past_date = create(:goal,
                                     owner: teammate,
                                     creator: teammate,
                                     company: organization,
                                     started_at: 1.day.ago,
                                     most_likely_target_date: 1.year.ago,
                                     completed_at: nil,
                                     deleted_at: nil)

        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include(goal_with_past_date.title)
        expect(response.body).to include("#{person.casual_name} has")
        expect(response.body).to include("active goal")
      end

      it 'expanded goals table has no Timeframe column and Last Confidence uses sentence format' do
        reporter = create(:person, first_name: 'Sam', last_name: 'Reporter')
        ct = CompanyTeammate.find(teammate.id)
        goal = create(:goal,
                     owner: ct,
                     creator: ct,
                     company: organization,
                     title: 'Goal With Check-in',
                     started_at: 1.day.ago,
                     most_likely_target_date: 2.months.from_now,
                     completed_at: nil,
                     deleted_at: nil)
        create(:goal_check_in,
               goal: goal,
               check_in_week_start: Date.current.beginning_of_week(:monday),
               confidence_reporter: reporter,
               confidence_percentage: 85)
        get about_me_organization_company_teammate_path(organization, teammate)
        body = response.body
        expect(body).not_to match(/<th[^>]*>\s*Timeframe\s*<\/th>/i)
        expect(body).to include(reporter.casual_name)
        expect(body).to include('85%')
        expect(body).to include('this will be hit by')
        expect(body).to include(goal.most_likely_target_date.strftime('%b %d, %Y'))
      end

      it 'status indicator and view show same goals count' do
        # Create goals with and without target dates
        goal_with_date = create(:goal,
                               owner: teammate,
                               creator: teammate,
                               company: organization,
                               started_at: 1.day.ago,
                               most_likely_target_date: 1.month.from_now,
                               completed_at: nil,
                               deleted_at: nil)
        goal_without_date = create(:goal,
                                  owner: teammate,
                                  creator: teammate,
                                  company: organization,
                                  started_at: 1.day.ago,
                                  most_likely_target_date: nil,
                                  completed_at: nil,
                                  deleted_at: nil)

        get about_me_organization_company_teammate_path(organization, teammate)
        # Both goals should be shown
        expect(response.body).to include(goal_with_date.title)
        expect(response.body).to include(goal_without_date.title)
        expect(response.body).to include("2 active goals")
      end

      it 'shows only goals owned by the about-me teammate, not goals where they are only creator' do
        other_person = create(:person)
        other_teammate = create(:company_teammate, person: other_person, organization: organization)
        create(:employment_tenure, teammate: other_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)

        create(:goal,
               title: 'Goal I own',
               owner: teammate,
               creator: teammate,
               company: organization,
               started_at: 1.day.ago,
               completed_at: nil,
               deleted_at: nil)
        # Goal owned by other_teammate but created by teammate - should NOT appear on teammate's about_me
        create(:goal,
               title: 'Goal owned by other person',
               owner: other_teammate,
               creator: teammate,
               company: organization,
               started_at: 1.day.ago,
               completed_at: nil,
               deleted_at: nil)

        get about_me_organization_company_teammate_path(organization, teammate)

        expect(response.body).to include('Goal I own')
        expect(response.body).not_to include('Goal owned by other person')
        expect(response.body).to include('1 active goal')
      end

      it 'orders goals hierarchically: each parent immediately followed by its children' do
        ct = CompanyTeammate.find(teammate.id)
        parent_a = create(:goal,
                         title: 'Parent Objective',
                         owner: ct,
                         creator: ct,
                         company: organization,
                         started_at: 1.day.ago,
                         most_likely_target_date: 2.months.from_now,
                         completed_at: nil,
                         deleted_at: nil)
        child_a = create(:goal,
                        title: 'Child Key Result',
                        owner: ct,
                        creator: ct,
                        company: organization,
                        started_at: 1.day.ago,
                        most_likely_target_date: 2.months.from_now + 1.day,
                        completed_at: nil,
                        deleted_at: nil)
        create(:goal_link, parent: parent_a, child: child_a)
        parent_b = create(:goal,
                         title: 'Other Parent',
                         owner: ct,
                         creator: ct,
                         company: organization,
                         started_at: 1.day.ago,
                         most_likely_target_date: 2.months.from_now,
                         completed_at: nil,
                         deleted_at: nil)
        child_b = create(:goal,
                         title: 'Other Child',
                         owner: ct,
                         creator: ct,
                         company: organization,
                         started_at: 1.day.ago,
                         completed_at: nil,
                         deleted_at: nil)
        create(:goal_link, parent: parent_b, child: child_b)
        get about_me_organization_company_teammate_path(organization, teammate)
        body = response.body
        # Roots sorted by date then title, so "Other Parent" before "Parent Objective"; each child directly under its parent
        pos_parent_a = body.index('Parent Objective')
        pos_child_a = body.index('Child Key Result')
        pos_parent_b = body.index('Other Parent')
        pos_child_b = body.index('Other Child')
        expect(pos_parent_b).to be < pos_child_b
        expect(pos_child_b).to be < pos_parent_a
        expect(pos_parent_a).to be < pos_child_a
      end

      it 'prefixes child goals with same icon as prompt edit page (bi-arrow-90deg-down)' do
        ct = CompanyTeammate.find(teammate.id)
        parent = create(:goal,
                        title: 'Parent Goal',
                        owner: ct,
                        creator: ct,
                        company: organization,
                        started_at: 1.day.ago,
                        completed_at: nil,
                        deleted_at: nil)
        child = create(:goal,
                      title: 'Child Goal',
                      owner: ct,
                      creator: ct,
                      company: organization,
                      started_at: 1.day.ago,
                      completed_at: nil,
                      deleted_at: nil)
        create(:goal_link, parent: parent, child: child)
        get about_me_organization_company_teammate_path(organization, teammate)
        # Child row should contain the same icon as prompt edit: bi-arrow-90deg-down and rotate-270
        expect(response.body).to include('bi-arrow-90deg-down')
        expect(response.body).to include('rotate-270')
        expect(response.body).to include('Child Goal')
      end
    end

    context '1:1 section' do
      it 'shows red indicator when no link saved' do
        get about_me_organization_company_teammate_path(organization, teammate)
        # Should show red indicator when no 1:1 link
        expect(response.body).to match(/text-danger|bg-danger/)
      end

      it 'displays cached project summary when cache exists' do
        one_on_one_link = create(:one_on_one_link, teammate: teammate, url: 'https://app.asana.com/0/123456/789')
        cache = create(:external_project_cache, 
                      cacheable: one_on_one_link, 
                      source: 'asana',
                      items_data: [
                        { 'gid' => '1', 'name' => 'Task 1', 'completed' => false, 'section_gid' => 'section_1' },
                        { 'gid' => '2', 'name' => 'Task 2', 'completed' => true, 'completed_at' => 5.days.ago.iso8601, 'section_gid' => 'section_1' }
                      ],
                      sections_data: [
                        { 'gid' => 'section_1', 'name' => 'Section 1', 'position' => 0 }
                      ])
        
        get about_me_organization_company_teammate_path(organization, teammate)
        
        expect(response).to have_http_status(:success)
        expect(response.body).to include('1:1 Area')
        expect(response.body).to include('incomplete task')
        expect(response.body).to include('recently completed task')
      end
    end

    context 'prompts section' do
      context 'when company has no active prompts' do
        it 'hides the prompts section entirely' do
          get about_me_organization_company_teammate_path(organization, teammate)
          expect(response.body).not_to match(/Prompts.*Reflections/i)
        end
      end

      context 'when company has active prompts' do
        let!(:prompt_template) do
          create(:prompt_template, company: organization, available_at: 1.day.ago)
        end

        context 'when user has no prompts or no responses' do
          it 'shows red indicator' do
            get about_me_organization_company_teammate_path(organization, teammate)
            expect(response.body).to match(/Prompts.*Reflections/i)
            expect(response.body).to match(/text-danger|alert-danger/)
          end
        end

        context 'when user has responses but no active goals' do
          let!(:prompt) do
            # Reload as CompanyTeammate to ensure correct type
            company_teammate = CompanyTeammate.find(teammate.id)
            create(:prompt, company_teammate: company_teammate, prompt_template: prompt_template)
          end
          let!(:prompt_question) do
            create(:prompt_question, prompt_template: prompt_template, position: 1)
          end
          let!(:prompt_answer) do
            create(:prompt_answer, prompt: prompt, prompt_question: prompt_question, text: 'My answer')
          end

          it 'shows yellow indicator' do
            get about_me_organization_company_teammate_path(organization, teammate)
            expect(response.body).to match(/Prompts.*Reflections/i)
            expect(response.body).to match(/text-warning|alert-warning/)
          end
        end

        context 'when user has responses and active goals associated with prompts' do
          let!(:prompt) do
            # Reload as CompanyTeammate to ensure correct type
            company_teammate = CompanyTeammate.find(teammate.id)
            create(:prompt, company_teammate: company_teammate, prompt_template: prompt_template)
          end
          let!(:prompt_question) do
            create(:prompt_question, prompt_template: prompt_template, position: 1)
          end
          let!(:prompt_answer) do
            create(:prompt_answer, prompt: prompt, prompt_question: prompt_question, text: 'My answer')
          end
          let!(:goal) do
            company_teammate = CompanyTeammate.find(teammate.id)
            create(:goal, 
                   owner: company_teammate, 
                   creator: company_teammate, 
                   company: organization,
                   started_at: 1.day.ago,
                   deleted_at: nil,
                   completed_at: nil)
          end
          let!(:prompt_goal) do
            create(:prompt_goal, prompt: prompt, goal: goal)
          end

          it 'shows green indicator' do
            get about_me_organization_company_teammate_path(organization, teammate)
            expect(response.body).to match(/Prompts.*Reflections/i)
            expect(response.body).to match(/text-success|alert-success/)
          end

          it 'shows summary with statistics' do
            get about_me_organization_company_teammate_path(organization, teammate)
            # Section uses company_label; default is "Prompt(s)" / "Reflection(s)"
            expect(response.body).to match(/Prompts?.*Reflections?|Reflections?.*Prompts?/i)
            expect(response.body).to include(teammate.person.casual_name)
            expect(response.body).to include('has started')
            expect(response.body).to include('has answered')
            expect(response.body).to include('of the total')
            expect(response.body).to include('questions')
            expect(response.body).to include('total goals associated with')
            expect(response.body).to match(/of these (prompts|reflections)/i)
          end

          it 'shows View All growth plans link when viewing own about me' do
            get about_me_organization_company_teammate_path(organization, teammate)
            expect(response.body).to match(/View All.*Prompt/i)
          end

          context 'when prompt is open' do
            it 'shows prompt in expanded view with goal count' do
              get about_me_organization_company_teammate_path(organization, teammate)
              expect(response.body).to include(prompt_template.title)
              expect(response.body).to include('goals')
            end

            context 'when all goals are started' do
              let!(:goal2) do
                company_teammate = CompanyTeammate.find(teammate.id)
                create(:goal, 
                       owner: company_teammate, 
                       creator: company_teammate, 
                       company: organization,
                       started_at: 1.day.ago,
                       deleted_at: nil,
                       completed_at: nil)
              end
              let!(:prompt_goal2) do
                create(:prompt_goal, prompt: prompt, goal: goal2)
              end

              it 'shows "all started" in goal count' do
                get about_me_organization_company_teammate_path(organization, teammate)
                expect(response.body).to include('goals with')
                expect(response.body).to include('all')
                expect(response.body).to include('started')
              end
            end

            context 'when some goals are started' do
              let!(:goal2) do
                company_teammate = CompanyTeammate.find(teammate.id)
                create(:goal, 
                       owner: company_teammate, 
                       creator: company_teammate, 
                       company: organization,
                       started_at: nil,
                       deleted_at: nil,
                       completed_at: nil)
              end
              let!(:prompt_goal2) do
                create(:prompt_goal, prompt: prompt, goal: goal2)
              end

              it 'shows count of started goals' do
                get about_me_organization_company_teammate_path(organization, teammate)
                expect(response.body).to include('goals with')
                expect(response.body).to include('started')
                expect(response.body).not_to include('all started')
              end
            end

            context 'when no goals are started' do
              let!(:goal2) do
                company_teammate = CompanyTeammate.find(teammate.id)
                create(:goal, 
                       owner: company_teammate, 
                       creator: company_teammate, 
                       company: organization,
                       started_at: nil,
                       deleted_at: nil,
                       completed_at: nil)
              end
              let!(:prompt_goal2) do
                create(:prompt_goal, prompt: prompt, goal: goal2)
              end

              before do
                goal.update!(started_at: nil)
              end

              it 'shows only goal count without started count' do
                get about_me_organization_company_teammate_path(organization, teammate)
                # Should show goals count in the list item
                # Extract the list-group-item section to check goal count text
                html = Nokogiri::HTML(response.body)
                list_items = html.css('.list-group-item')
                goal_count_text = list_items.find { |item| item.text.include?('goals') }&.text
                
                expect(goal_count_text).to be_present
                expect(goal_count_text).to match(/\d+\s+goals/)
                # Should not have "with X started" or "with all started" pattern
                expect(goal_count_text).not_to match(/goals\s+with\s+(\d+|all)\s+started/i)
              end
            end
          end

          context 'when prompt is closed' do
            before do
              prompt.update!(closed_at: 1.day.ago)
            end

            it 'does not show prompt in expanded view' do
              get about_me_organization_company_teammate_path(organization, teammate)
              expect(response.body).not_to include(prompt_template.title)
            end
          end
        end

        context 'when viewing another teammate\'s about me' do
          let(:viewer_person) { person }
          let(:viewer_teammate) { teammate }
          let(:about_me_person) { create(:person) }
          let(:about_me_teammate) do
            ct = create(:company_teammate, person: about_me_person, organization: organization)
            create(:employment_tenure, teammate: ct, company: organization, manager: viewer_person, started_at: 1.year.ago, ended_at: nil)
            ct.update!(first_employed_at: 1.year.ago)
            ct
          end
          let!(:about_me_prompt) do
            create(:prompt, :open, company_teammate: about_me_teammate, prompt_template: prompt_template)
          end

          before do
            allow_any_instance_of(CompanyTeammatePolicy).to receive(:view_check_ins?).and_return(true)
            sign_in_as_teammate_for_request(viewer_person, organization)
          end

          it 'links View to the about-me teammate\'s prompt edit page, not the viewer\'s' do
            get about_me_organization_company_teammate_path(organization, about_me_teammate)
            expect(response).to have_http_status(:success)

            expected_path = edit_organization_prompt_path(organization, about_me_prompt)
            expect(response.body).to include(expected_path)

            # Prompts section only shows @open_prompts for the about-me teammate; View link must be that teammate's prompt
            prompts_section = Nokogiri::HTML(response.body).at_css('#promptsSection')
            expect(prompts_section).to be_present
            expect(prompts_section.to_s).to include(expected_path)

            # If viewer has their own prompt, the prompts section must not link to it (only about-me teammate's prompts)
            viewer_prompt = Prompt.find_by(company_teammate: viewer_teammate, prompt_template: prompt_template)
            if viewer_prompt && viewer_prompt.id != about_me_prompt.id
              viewer_prompt_path = edit_organization_prompt_path(organization, viewer_prompt)
              expect(prompts_section.to_s).not_to include(viewer_prompt_path)
            end
          end

          it 'does not show View All growth plans link when viewing another teammate\'s about me' do
            get about_me_organization_company_teammate_path(organization, about_me_teammate)
            prompts_section = Nokogiri::HTML(response.body).at_css('#promptsSection')
            expect(prompts_section).to be_present
            expect(prompts_section.to_s).not_to match(/View All.*Prompt/i)
          end
        end
      end
    end
  end

  describe 'Onboarding Spotlight' do
    context 'when viewing own page with no observations and no goals' do
      it 'shows the onboarding spotlight' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include('Welcome to OurGruuv!')
        expect(response.body).to include('Clarity and Continuous Feedback')
        expect(assigns(:show_onboarding_spotlight)).to be true
      end

      it 'shows all three milestones' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include('Milestone 1')
        expect(response.body).to include('Milestone 2')
        expect(response.body).to include('Milestone 3')
      end

      it 'shows milestone 1 as complete' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include('Logging In')
        expect(response.body).to include('Complete')
      end

      it 'shows milestone 2 as incomplete with link to create observation' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include('Adding a Kudos, Feedback, or Observation')
        expect(response.body).to include('Add Observation')
        expect(response.body).to include(select_type_organization_observations_path(organization))
      end

      it 'shows milestone 3 as incomplete with link to create goal' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include('Setting Goals with Weekly Check-ins')
        expect(response.body).to include('Create Goal')
        expect(response.body).to include(new_organization_goal_path(organization))
      end
    end

    context 'when viewing someone else\'s page' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:company_teammate, person: other_person, organization: organization) }

      before do
        create(:employment_tenure, teammate: other_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        other_teammate.update!(first_employed_at: 1.year.ago)
        # Give permission to view other teammate's about_me page
        allow_any_instance_of(CompanyTeammatePolicy).to receive(:view_check_ins?).and_return(true)
      end

      it 'does not show the onboarding spotlight' do
        get about_me_organization_company_teammate_path(organization, other_teammate)
        expect(response.body).not_to include('Welcome to OurGruuv!')
        expect(assigns(:show_onboarding_spotlight)).to be false
      end
    end

    context 'when user has observations but no goals' do
      let!(:observation) do
        build(:observation,
              observer: person,
              company: organization,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago,
              published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end
      end

      it 'shows the onboarding spotlight' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include('Welcome to OurGruuv!')
        expect(assigns(:show_onboarding_spotlight)).to be true
        expect(assigns(:has_observations)).to be true
        expect(assigns(:has_goals)).to be false
      end
    end

    context 'when user has goals but no observations' do
      let!(:goal) do
        create(:goal,
               owner: teammate,
               creator: teammate,
               company: organization,
               started_at: 1.day.ago,
               completed_at: nil,
               deleted_at: nil)
      end

      it 'shows the onboarding spotlight' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include('Welcome to OurGruuv!')
        expect(assigns(:show_onboarding_spotlight)).to be true
        expect(assigns(:has_observations)).to be false
        expect(assigns(:has_goals)).to be true
      end
    end

    context 'when user has both observations and goals' do
      let!(:observation) do
        build(:observation,
              observer: person,
              company: organization,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago,
              published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end
      end

      let!(:goal) do
        create(:goal,
               owner: teammate,
               creator: teammate,
               company: organization,
               started_at: 1.day.ago,
               completed_at: nil,
               deleted_at: nil)
      end

      it 'does not show the onboarding spotlight' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).not_to include('Welcome to OurGruuv!')
        expect(assigns(:show_onboarding_spotlight)).to be false
        expect(assigns(:has_observations)).to be true
        expect(assigns(:has_goals)).to be true
      end
    end

    context 'when user has draft observation but no goals' do
      let!(:draft_observation) do
        create(:observation,
               observer: person,
               company: organization,
               privacy_level: :public_to_company,
               observed_at: 10.days.ago,
               published_at: nil)
      end

      it 'shows the onboarding spotlight' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include('Welcome to OurGruuv!')
        expect(assigns(:show_onboarding_spotlight)).to be true
        expect(assigns(:has_observations)).to be true
        expect(assigns(:has_goals)).to be false
      end
    end

    context 'when user has draft goal but no observations' do
      let!(:draft_goal) do
        create(:goal,
               owner: teammate,
               creator: teammate,
               company: organization,
               started_at: nil,
               deleted_at: nil)
      end

      it 'shows the onboarding spotlight' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include('Welcome to OurGruuv!')
        expect(assigns(:show_onboarding_spotlight)).to be true
        expect(assigns(:has_observations)).to be false
        expect(assigns(:has_goals)).to be true
      end
    end

    context 'when user has archived observation but no goals' do
      let!(:archived_observation) do
        create(:observation,
               observer: person,
               company: organization,
               privacy_level: :public_to_company,
               observed_at: 10.days.ago,
               published_at: 10.days.ago,
               deleted_at: 1.day.ago)
      end

      it 'shows the onboarding spotlight' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include('Welcome to OurGruuv!')
        expect(assigns(:show_onboarding_spotlight)).to be true
        expect(assigns(:has_observations)).to be true
        expect(assigns(:has_goals)).to be false
      end
    end

    context 'when user has completed goal but no observations' do
      let!(:completed_goal) do
        create(:goal,
               owner: teammate,
               creator: teammate,
               company: organization,
               started_at: 60.days.ago,
               completed_at: 30.days.ago,
               deleted_at: nil)
      end

      it 'shows the onboarding spotlight' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include('Welcome to OurGruuv!')
        expect(assigns(:show_onboarding_spotlight)).to be true
        expect(assigns(:has_observations)).to be false
        expect(assigns(:has_goals)).to be true
      end
    end

    context 'when company preference is disabled' do
      before do
        company = organization.root_company || organization
        create(:company_label_preference, company: company, label_key: 'encourage_goal_and_observation', label_value: 'false')
      end

      context 'when viewing own page with no observations and no goals' do
        it 'does not show the onboarding spotlight' do
          get about_me_organization_company_teammate_path(organization, teammate)
          expect(response.body).not_to include('Welcome to OurGruuv!')
          expect(assigns(:show_onboarding_spotlight)).to be false
        end
      end

      context 'when user has observations but no goals' do
        let!(:observation) do
          build(:observation,
                observer: person,
                company: organization,
                privacy_level: :public_to_company,
                observed_at: 10.days.ago,
                published_at: 10.days.ago).tap do |obs|
            obs.observees.build(teammate: teammate)
            obs.save!
          end
        end

        it 'does not show the onboarding spotlight' do
          get about_me_organization_company_teammate_path(organization, teammate)
          expect(response.body).not_to include('Welcome to OurGruuv!')
          expect(assigns(:show_onboarding_spotlight)).to be false
        end
      end

      context 'when user has goals but no observations' do
        let!(:goal) do
          create(:goal,
                 owner: teammate,
                 creator: teammate,
                 company: organization,
                 started_at: 1.day.ago,
                 completed_at: nil,
                 deleted_at: nil)
        end

        it 'does not show the onboarding spotlight' do
          get about_me_organization_company_teammate_path(organization, teammate)
          expect(response.body).not_to include('Welcome to OurGruuv!')
          expect(assigns(:show_onboarding_spotlight)).to be false
        end
      end
    end

    context 'when company preference is enabled' do
      before do
        company = organization.root_company || organization
        create(:company_label_preference, company: company, label_key: 'encourage_goal_and_observation', label_value: 'true')
      end

      context 'when viewing own page with no observations and no goals' do
        it 'shows the onboarding spotlight' do
          get about_me_organization_company_teammate_path(organization, teammate)
          expect(response.body).to include('Welcome to OurGruuv!')
          expect(assigns(:show_onboarding_spotlight)).to be true
        end
      end
    end

    context 'when company preference is not set (default behavior)' do
      before do
        # Ensure no preference exists
        company = organization.root_company || organization
        CompanyLabelPreference.where(company: company, label_key: 'encourage_goal_and_observation').destroy_all
      end

      context 'when viewing own page with no observations and no goals' do
        it 'shows the onboarding spotlight (defaults to enabled)' do
          get about_me_organization_company_teammate_path(organization, teammate)
          expect(response.body).to include('Welcome to OurGruuv!')
          expect(assigns(:show_onboarding_spotlight)).to be true
        end
      end
    end
  end

  describe 'Viewer check-in readiness sentence (collapsed sections)' do
    it 'sets viewing_own_about_me to true when viewing own page' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(assigns(:viewing_own_about_me)).to be true
      expect(assigns(:viewer_ready_aspiration_count)).to eq(0)
      expect(assigns(:viewer_ready_assignment_count)).to eq(0)
      expect(assigns(:viewer_ready_position)).to be false
    end

    it 'does not show "You have completed your side" when viewing own page with no completed check-ins' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).not_to include('You have completed your side of the check-in')
    end

    context 'when viewing own page and viewer (employee) has completed their side' do
      let(:title) { create(:title, company: organization) }
      let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
      let(:position) { create(:position, title: title, position_level: position_level) }
      let(:required_assignment) { create(:assignment, company: organization) }
      let!(:aspiration1) { create(:aspiration, company: organization, name: 'Aspiration 1') }
      let!(:aspiration2) { create(:aspiration, company: organization, name: 'Aspiration 2') }

      before do
        EmploymentTenure.where(company_teammate: teammate, company: organization, ended_at: nil).update_all(ended_at: 2.years.ago)
        create(:employment_tenure, teammate: teammate, company: organization, position: position, started_at: 1.year.ago, ended_at: nil)
        teammate.reload
        actual_position = teammate.active_employment_tenure.position
        create(:position_assignment, position: actual_position, assignment: required_assignment, assignment_type: 'required')
        create(:assignment_tenure, teammate: teammate, assignment: required_assignment, anticipated_energy_percentage: 50, started_at: 1.month.ago, ended_at: nil)
        # Viewer (teammate) has completed employee side for one aspiration, one assignment, and position
        create(:aspiration_check_in, teammate: teammate, aspiration: aspiration1, employee_completed_at: 1.day.ago)
        create(:assignment_check_in, teammate: teammate, assignment: required_assignment, employee_completed_at: 1.day.ago)
        position_check_in = PositionCheckIn.find_or_create_open_for(teammate)
        position_check_in.update!(employee_completed_at: 1.day.ago)
      end

      it 'sets viewing_own_about_me and viewer readiness counts' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(assigns(:viewing_own_about_me)).to be true
        expect(assigns(:viewer_ready_aspiration_count)).to eq(1)
        expect(assigns(:viewer_ready_assignment_count)).to eq(1)
        expect(assigns(:viewer_ready_position)).to be true
      end

      it 'shows aspirational values viewer sentence in collapsed summary' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include('You have completed your side of the check-in for 1 of the 2 aspirational values')
      end

      it 'shows assignments viewer sentence in collapsed summary' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include('You have completed your side of the check-in for 1 of the 1 assignment')
      end

      it 'shows position viewer sentence in collapsed summary (no X of Y)' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include('You have completed your side of the check-in.')
      end
    end

    context 'when viewing another teammate\'s about me' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:company_teammate, person: other_person, organization: organization) }

      before do
        create(:employment_tenure, teammate: other_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        other_teammate.update!(first_employed_at: 1.year.ago)
        allow_any_instance_of(CompanyTeammatePolicy).to receive(:view_check_ins?).and_return(true)
        sign_in_as_teammate_for_request(other_person, organization)
      end

      it 'sets viewing_own_about_me to false and does not show viewer sentence' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(assigns(:viewing_own_about_me)).to be false
        expect(assigns(:viewer_ready_aspiration_count)).to eq(0)
        expect(assigns(:viewer_ready_assignment_count)).to eq(0)
        expect(assigns(:viewer_ready_position)).to be false
        expect(response.body).not_to match(/You have completed your side of the check-in/)
      end
    end
  end
end

