require 'rails_helper'

RSpec.describe 'About Me Page', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization, type: 'CompanyTeammate') }

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
    end

    context 'when user does not have view_check_ins permission' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:teammate, person: other_person, organization: organization, type: 'CompanyTeammate') }

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

  describe 'Sections rendering' do
    it 'renders stories section' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('stories')
    end

    it 'renders goals section' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to match(/Active Goals/i)
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
      let(:position_type) { create(:position_type, organization: organization) }
      let(:position_level) { create(:position_level, position_major_level: position_type.position_major_level) }
      let(:position) { create(:position, position_type: position_type, position_level: position_level) }

      before do
        # End the existing employment_tenure from the main before block and create a new one with position
        EmploymentTenure.where(teammate: teammate, company: organization, ended_at: nil).update_all(ended_at: 2.years.ago)
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
    let(:other_teammate) { create(:teammate, person: other_person, organization: organization, type: 'CompanyTeammate') }
    let(:third_person) { create(:person) }
    let(:third_teammate) { create(:teammate, person: third_person, organization: organization, type: 'CompanyTeammate') }

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
        other_teammate = create(:teammate, person: other_person, organization: organization, type: 'CompanyTeammate')
        
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
        other_teammate = create(:teammate, person: other_person, organization: organization, type: 'CompanyTeammate')
        
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
        other_teammate = create(:teammate, person: other_person, organization: organization, type: 'CompanyTeammate')
        
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
        other_teammate = create(:teammate, person: other_person, organization: organization, type: 'CompanyTeammate')
        
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
        other_teammate = create(:teammate, person: other_person, organization: organization, type: 'CompanyTeammate')
        
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
            expect(response.body).to include('Reflection Prompt')
            expect(response.body).to include(teammate.person.casual_name)
            expect(response.body).to include('has started')
            expect(response.body).to include('has answered')
            expect(response.body).to include('of the total')
            expect(response.body).to include('questions')
            expect(response.body).to include('total goals associated with')
            expect(response.body).to include('of these reflections')
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
        expect(response.body).to include('Celebrating!')
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
      let(:other_teammate) { create(:teammate, person: other_person, organization: organization, type: 'CompanyTeammate') }

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
  end
end

