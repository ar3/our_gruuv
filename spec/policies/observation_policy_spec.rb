require 'rails_helper'

RSpec.describe ObservationPolicy, type: :policy do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { CompanyTeammate.create!(person: observer, organization: company) }
  let(:observee_person) { create(:person) }
  let(:observee_teammate) { CompanyTeammate.create!(person: observee_person, organization: company) }
  let(:manager_person) { create(:person) }
  let(:manager_teammate) { CompanyTeammate.create!(person: manager_person, organization: company) }
  let(:admin_person) { create(:person) }
  let(:admin_teammate) { CompanyTeammate.create!(person: admin_person, organization: company) }
  let(:random_person) { create(:person) }
  let(:random_teammate) { CompanyTeammate.create!(person: random_person, organization: company) }

  let(:pundit_user_observer) { OpenStruct.new(user: observer_teammate, impersonating_teammate: nil) }
  let(:pundit_user_observee) { OpenStruct.new(user: observee_teammate, impersonating_teammate: nil) }
  let(:pundit_user_manager) { OpenStruct.new(user: manager_teammate, impersonating_teammate: nil) }
  let(:pundit_user_admin) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }
  let(:pundit_user_random) { OpenStruct.new(user: random_teammate, impersonating_teammate: nil) }

  let(:observation) do
    build(:observation, observer: observer, company: company, privacy_level: :observed_only).tap do |obs|
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs.publish!
    end
  end

  before do
    # Skip this setup for the comprehensive visibility matrix spec
    next if RSpec.current_example&.metadata[:isolated]
    
    # Set up real employment tenures to create managerial hierarchy
    # Manager is direct manager of observee
    create(:employment_tenure, teammate: manager_teammate, company: company)
    create(:employment_tenure, teammate: observee_teammate, company: company, manager: manager_person)
    
    # Admin has employment management permissions
    admin_teammate.update!(can_manage_employment: true)
    create(:employment_tenure, teammate: admin_teammate, company: company)
    
    # Reload manager_teammate to clear association cache
    manager_teammate.reload
  end

  describe '#show?' do
    context 'observer_only privacy' do
      let(:observer_only_obs) do
        build(:observation, observer: observer, company: company, privacy_level: :observer_only).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
        end
      end

      it 'allows observer' do
        policy = ObservationPolicy.new(pundit_user_observer, observer_only_obs)
        expect(policy.show?).to be true
      end

      it 'denies everyone else' do
        observee_policy = ObservationPolicy.new(pundit_user_observee, observer_only_obs)
        manager_policy = ObservationPolicy.new(pundit_user_manager, observer_only_obs)
        random_policy = ObservationPolicy.new(pundit_user_random, observer_only_obs)

        expect(observee_policy.show?).to be false
        expect(manager_policy.show?).to be false
        expect(random_policy.show?).to be false
      end
    end

    context 'observed_only privacy' do
      it 'allows observer and observee' do
        observer_policy = ObservationPolicy.new(pundit_user_observer, observation)
        observee_policy = ObservationPolicy.new(pundit_user_observee, observation)

        expect(observer_policy.show?).to be true
        expect(observee_policy.show?).to be true
      end

      it 'denies manager even if they manage the observee' do
        manager_policy = ObservationPolicy.new(pundit_user_manager, observation)
        expect(manager_policy.show?).to be false
      end

      it 'denies random person' do
        random_policy = ObservationPolicy.new(pundit_user_random, observation)
        expect(random_policy.show?).to be false
      end

      context 'when employee observes themselves' do
        let(:self_observation) do
          build(:observation, observer: observee_person, company: company, privacy_level: :observed_only).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end

        it 'allows employee to see their own self-observation' do
          policy = ObservationPolicy.new(pundit_user_observee, self_observation)
          expect(policy.show?).to be true
        end

        it 'denies manager from seeing employee self-observation' do
          manager_policy = ObservationPolicy.new(pundit_user_manager, self_observation)
          expect(manager_policy.show?).to be false
        end
      end
    end

    context 'managers_only privacy' do
      let(:managers_only_obs) do
        build(:observation, observer: observer, company: company, privacy_level: :managers_only).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
        end
      end

      it 'allows observer and direct manager' do
        # Reload manager_teammate to ensure fresh data
        manager_teammate.reload
        # Reload the observation to ensure all associations are fresh
        managers_only_obs.reload
        
        observer_policy = ObservationPolicy.new(pundit_user_observer, managers_only_obs)
        manager_policy = ObservationPolicy.new(pundit_user_manager, managers_only_obs)

        expect(observer_policy.show?).to be true
        expect(manager_policy.show?).to be true
      end

      it 'allows indirect manager (grand manager)' do
        grand_manager = create(:person)
        grand_manager_teammate = CompanyTeammate.create!(person: grand_manager, organization: company)
        grand_manager_pundit_user = OpenStruct.new(user: grand_manager_teammate, impersonating_teammate: nil)
        
        # Set up hierarchy: observee -> manager -> grand_manager
        # Create employment tenure for grand_manager first
        create(:employment_tenure, teammate: grand_manager_teammate, company: company)
        # Delete and recreate manager tenure with grand_manager as manager to avoid association caching issues
        manager_tenure = EmploymentTenure.find_by(teammate: manager_teammate, company: company)
        manager_tenure.destroy
        create(:employment_tenure, teammate: manager_teammate, company: company, manager: grand_manager)
        # Reload manager and grand_manager teammates to clear association cache
        manager_teammate.reload
        grand_manager_teammate.reload
        # Reload observation to clear association cache for observed_teammates
        managers_only_obs.reload

        grand_manager_policy = ObservationPolicy.new(grand_manager_pundit_user, managers_only_obs)
        expect(grand_manager_policy.show?).to be true
      end

      it 'denies observee' do
        observee_policy = ObservationPolicy.new(pundit_user_observee, managers_only_obs)
        expect(observee_policy.show?).to be false
      end

      it 'denies random person' do
        random_policy = ObservationPolicy.new(pundit_user_random, managers_only_obs)
        expect(random_policy.show?).to be false
      end
    end

    context 'observed_and_managers privacy' do
      let(:observed_and_managers_obs) do
        build(:observation, observer: observer, company: company, privacy_level: :observed_and_managers).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
        end
      end

      it 'allows observer, observee, and direct manager' do
        # Reload manager_teammate to ensure fresh data
        manager_teammate.reload
        # Reload the observation to ensure all associations are fresh
        observed_and_managers_obs.reload
        
        observer_policy = ObservationPolicy.new(pundit_user_observer, observed_and_managers_obs)
        observee_policy = ObservationPolicy.new(pundit_user_observee, observed_and_managers_obs)
        manager_policy = ObservationPolicy.new(pundit_user_manager, observed_and_managers_obs)

        expect(observer_policy.show?).to be true
        expect(observee_policy.show?).to be true
        expect(manager_policy.show?).to be true
      end

      it 'allows indirect manager (grand manager)' do
        grand_manager = create(:person)
        grand_manager_teammate = CompanyTeammate.create!(person: grand_manager, organization: company)
        grand_manager_pundit_user = OpenStruct.new(user: grand_manager_teammate, impersonating_teammate: nil)
        
        # Set up hierarchy: observee -> manager -> grand_manager
        create(:employment_tenure, teammate: grand_manager_teammate, company: company)
        # Delete and recreate manager tenure with grand_manager as manager to avoid association caching issues
        manager_tenure = EmploymentTenure.find_by(teammate: manager_teammate, company: company)
        manager_tenure.destroy
        create(:employment_tenure, teammate: manager_teammate, company: company, manager: grand_manager)
        # Reload teammates to clear association cache
        manager_teammate.reload
        grand_manager_teammate.reload
        # Reload observation to clear association cache for observed_teammates
        observed_and_managers_obs.reload
        
        grand_manager_policy = ObservationPolicy.new(grand_manager_pundit_user, observed_and_managers_obs)
        expect(grand_manager_policy.show?).to be true
      end

      it 'denies random person' do
        random_policy = ObservationPolicy.new(pundit_user_random, observed_and_managers_obs)
        expect(random_policy.show?).to be false
      end
    end

    context 'public_to_company privacy' do
      let(:company_public_obs) do
        build(:observation, observer: observer, company: company, privacy_level: :public_to_company).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
        end
      end

      it 'allows observer' do
        observer_policy = ObservationPolicy.new(pundit_user_observer, company_public_obs)
        expect(observer_policy.show?).to be true
      end

      it 'allows active company teammates' do
        observee_policy = ObservationPolicy.new(pundit_user_observee, company_public_obs)
        manager_policy = ObservationPolicy.new(pundit_user_manager, company_public_obs)
        random_policy = ObservationPolicy.new(pundit_user_random, company_public_obs)

        expect(observee_policy.show?).to be true
        expect(manager_policy.show?).to be true
        expect(random_policy.show?).to be true
      end

      it 'denies terminated teammates' do
        terminated_person = create(:person)
        terminated_teammate = CompanyTeammate.create!(person: terminated_person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: 1.day.ago)
        terminated_pundit_user = OpenStruct.new(user: terminated_teammate, impersonating_teammate: nil)

        terminated_policy = ObservationPolicy.new(terminated_pundit_user, company_public_obs)
        expect(terminated_policy.show?).to be false
      end

      it 'denies people from other companies' do
        other_company = create(:organization, :company)
        other_person = create(:person)
        other_teammate = CompanyTeammate.create!(person: other_person, organization: other_company)
        other_pundit_user = OpenStruct.new(user: other_teammate, impersonating_teammate: nil)

        other_policy = ObservationPolicy.new(other_pundit_user, company_public_obs)
        expect(other_policy.show?).to be false
      end
    end

    context 'public_to_world privacy' do
      let(:public_obs) do
        build(:observation, observer: observer, company: company, privacy_level: :public_to_world).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
        end
      end

      it 'allows observer' do
        observer_policy = ObservationPolicy.new(pundit_user_observer, public_obs)
        expect(observer_policy.show?).to be true
      end

      it 'allows active company teammates' do
        observee_policy = ObservationPolicy.new(pundit_user_observee, public_obs)
        manager_policy = ObservationPolicy.new(pundit_user_manager, public_obs)
        random_policy = ObservationPolicy.new(pundit_user_random, public_obs)

        expect(observee_policy.show?).to be true
        expect(manager_policy.show?).to be true
        expect(random_policy.show?).to be true
      end

      it 'denies terminated teammates' do
        terminated_person = create(:person)
        terminated_teammate = CompanyTeammate.create!(person: terminated_person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: 1.day.ago)
        terminated_pundit_user = OpenStruct.new(user: terminated_teammate, impersonating_teammate: nil)

        terminated_policy = ObservationPolicy.new(terminated_pundit_user, public_obs)
        expect(terminated_policy.show?).to be false
      end

      it 'denies people from other companies' do
        other_company = create(:organization, :company)
        other_person = create(:person)
        other_teammate = CompanyTeammate.create!(person: other_person, organization: other_company)
        other_pundit_user = OpenStruct.new(user: other_teammate, impersonating_teammate: nil)

        other_policy = ObservationPolicy.new(other_pundit_user, public_obs)
        expect(other_policy.show?).to be false
      end
    end

    context 'when viewing_teammate is nil' do
      it 'denies access' do
        policy = ObservationPolicy.new(nil, observation)
        expect(policy.show?).to be false
      end
    end
  end

  describe '#create?' do
    it 'allows any authenticated user' do
      policy = ObservationPolicy.new(pundit_user_observer, Observation.new)
      expect(policy.create?).to be true
    end

    it 'denies unauthenticated users' do
      policy = ObservationPolicy.new(nil, Observation.new)
      expect(policy.create?).to be false
    end
  end

  describe '#update?' do
    it 'allows observer' do
      policy = ObservationPolicy.new(pundit_user_observer, observation)
      expect(policy.update?).to be true
    end

    it 'denies non-observer' do
      policy = ObservationPolicy.new(pundit_user_observee, observation)
      expect(policy.update?).to be false
    end
  end

  describe '#view_permalink?' do
    context 'with draft observation' do
      let(:draft_observation) do
        build(:observation, observer: observer, company: company, privacy_level: :public_to_world, published_at: nil).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
        end
      end

      it 'denies everyone including observer (drafts cannot be viewed via permalink)' do
        observer_policy = ObservationPolicy.new(pundit_user_observer, draft_observation)
        observee_policy = ObservationPolicy.new(pundit_user_observee, draft_observation)
        manager_policy = ObservationPolicy.new(pundit_user_manager, draft_observation)
        random_policy = ObservationPolicy.new(pundit_user_random, draft_observation)

        expect(observer_policy.view_permalink?).to be false
        expect(observee_policy.view_permalink?).to be false
        expect(manager_policy.view_permalink?).to be false
        expect(random_policy.view_permalink?).to be false
      end
    end

    context 'with published observation' do
      context 'observer_only privacy' do
        let(:observer_only_obs) do
          build(:observation, observer: observer, company: company, privacy_level: :observer_only).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end

        it 'denies everyone including observer (only public_to_world can be viewed via permalink)' do
          observer_policy = ObservationPolicy.new(pundit_user_observer, observer_only_obs)
          observee_policy = ObservationPolicy.new(pundit_user_observee, observer_only_obs)
          manager_policy = ObservationPolicy.new(pundit_user_manager, observer_only_obs)
          random_policy = ObservationPolicy.new(pundit_user_random, observer_only_obs)

          expect(observer_policy.view_permalink?).to be false
          expect(observee_policy.view_permalink?).to be false
          expect(manager_policy.view_permalink?).to be false
          expect(random_policy.view_permalink?).to be false
        end
      end

      context 'observed_only privacy' do
        it 'denies everyone (only public_to_world can be viewed via permalink)' do
          observer_policy = ObservationPolicy.new(pundit_user_observer, observation)
          observee_policy = ObservationPolicy.new(pundit_user_observee, observation)
          manager_policy = ObservationPolicy.new(pundit_user_manager, observation)
          random_policy = ObservationPolicy.new(pundit_user_random, observation)
          admin_policy = ObservationPolicy.new(pundit_user_admin, observation)

          expect(observer_policy.view_permalink?).to be false
          expect(observee_policy.view_permalink?).to be false
          expect(manager_policy.view_permalink?).to be false
          expect(random_policy.view_permalink?).to be false
          expect(admin_policy.view_permalink?).to be false
        end

        context 'when employee observes themselves' do
          let(:self_observation) do
            build(:observation, observer: observee_person, company: company, privacy_level: :observed_only).tap do |obs|
              obs.observees.build(teammate: observee_teammate)
              obs.save!
              obs.publish!
            end
          end

          it 'denies everyone including employee (only public_to_world can be viewed via permalink)' do
            observee_policy = ObservationPolicy.new(pundit_user_observee, self_observation)
            manager_policy = ObservationPolicy.new(pundit_user_manager, self_observation)

            expect(observee_policy.view_permalink?).to be false
            expect(manager_policy.view_permalink?).to be false
          end
        end
      end

      context 'managers_only privacy' do
        let(:managers_only_obs) do
          build(:observation, observer: observer, company: company, privacy_level: :managers_only).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end

        it 'denies everyone (only public_to_world can be viewed via permalink)' do
          # Reload manager_teammate to ensure fresh data
          manager_teammate.reload
          # Reload the observation to ensure all associations are fresh
          managers_only_obs.reload
          
          observer_policy = ObservationPolicy.new(pundit_user_observer, managers_only_obs)
          manager_policy = ObservationPolicy.new(pundit_user_manager, managers_only_obs)
          observee_policy = ObservationPolicy.new(pundit_user_observee, managers_only_obs)

          expect(observer_policy.view_permalink?).to be false
          expect(manager_policy.view_permalink?).to be false
          expect(observee_policy.view_permalink?).to be false
        end

        it 'denies indirect manager (grand manager) (only public_to_world can be viewed via permalink)' do
          grand_manager = create(:person)
          grand_manager_teammate = CompanyTeammate.create!(person: grand_manager, organization: company)
          grand_manager_pundit_user = OpenStruct.new(user: grand_manager_teammate, impersonating_teammate: nil)
          
          # Set up hierarchy: observee -> manager -> grand_manager
          create(:employment_tenure, teammate: grand_manager_teammate, company: company)
          # Delete and recreate manager tenure with grand_manager as manager to avoid association caching issues
          manager_tenure = EmploymentTenure.find_by(teammate: manager_teammate, company: company)
          manager_tenure.destroy
          create(:employment_tenure, teammate: manager_teammate, company: company, manager: grand_manager)
          # Reload teammates to clear association cache
          manager_teammate.reload
          grand_manager_teammate.reload
          # Reload observation to clear association cache for observed_teammates
          managers_only_obs.reload
          
          grand_manager_policy = ObservationPolicy.new(grand_manager_pundit_user, managers_only_obs)
          expect(grand_manager_policy.view_permalink?).to be false
        end
      end

      context 'observed_and_managers privacy' do
        let(:observed_and_managers_obs) do
          build(:observation, observer: observer, company: company, privacy_level: :observed_and_managers).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end

        it 'denies everyone (only public_to_world can be viewed via permalink)' do
          # Reload manager_teammate to ensure fresh data
          manager_teammate.reload
          # Reload the observation to ensure all associations are fresh
          observed_and_managers_obs.reload
          
          observer_policy = ObservationPolicy.new(pundit_user_observer, observed_and_managers_obs)
          observee_policy = ObservationPolicy.new(pundit_user_observee, observed_and_managers_obs)
          manager_policy = ObservationPolicy.new(pundit_user_manager, observed_and_managers_obs)

          expect(observer_policy.view_permalink?).to be false
          expect(observee_policy.view_permalink?).to be false
          expect(manager_policy.view_permalink?).to be false
        end

        it 'denies indirect manager (grand manager) (only public_to_world can be viewed via permalink)' do
          grand_manager = create(:person)
          grand_manager_teammate = CompanyTeammate.create!(person: grand_manager, organization: company)
          grand_manager_pundit_user = OpenStruct.new(user: grand_manager_teammate, impersonating_teammate: nil)
          
          # Set up hierarchy: observee -> manager -> grand_manager
          create(:employment_tenure, teammate: grand_manager_teammate, company: company)
          # Delete and recreate manager tenure with grand_manager as manager to avoid association caching issues
          manager_tenure = EmploymentTenure.find_by(teammate: manager_teammate, company: company)
          manager_tenure.destroy
          create(:employment_tenure, teammate: manager_teammate, company: company, manager: grand_manager)
          # Reload teammates to clear association cache
          manager_teammate.reload
          grand_manager_teammate.reload
          # Reload observation to clear association cache for observed_teammates
          observed_and_managers_obs.reload
          
          grand_manager_policy = ObservationPolicy.new(grand_manager_pundit_user, observed_and_managers_obs)
          expect(grand_manager_policy.view_permalink?).to be false
        end
      end

      context 'public_to_world privacy' do
        let(:public_obs) do
          build(:observation, observer: observer, company: company, privacy_level: :public_to_world).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end

        it 'allows everyone including unauthenticated' do
          # Unauthenticated access
          unauthenticated_policy = ObservationPolicy.new(nil, public_obs)
          expect(unauthenticated_policy.view_permalink?).to be true

          # Authenticated access
          observer_policy = ObservationPolicy.new(pundit_user_observer, public_obs)
          observee_policy = ObservationPolicy.new(pundit_user_observee, public_obs)
          manager_policy = ObservationPolicy.new(pundit_user_manager, public_obs)
          random_policy = ObservationPolicy.new(pundit_user_random, public_obs)

          expect(observer_policy.view_permalink?).to be true
          expect(observee_policy.view_permalink?).to be true
          expect(manager_policy.view_permalink?).to be true
          expect(random_policy.view_permalink?).to be true
        end
      end

      context 'public_to_company privacy' do
        let(:company_public_obs) do
          build(:observation, observer: observer, company: company, privacy_level: :public_to_company).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end

        it 'denies unauthenticated access (no permalink)' do
          unauthenticated_policy = ObservationPolicy.new(nil, company_public_obs)
          expect(unauthenticated_policy.view_permalink?).to be false
        end

        it 'denies authenticated users (no permalink access)' do
          # public_to_company observations are visible through authenticated pages, not permalinks
          observer_policy = ObservationPolicy.new(pundit_user_observer, company_public_obs)
          observee_policy = ObservationPolicy.new(pundit_user_observee, company_public_obs)
          manager_policy = ObservationPolicy.new(pundit_user_manager, company_public_obs)
          random_policy = ObservationPolicy.new(pundit_user_random, company_public_obs)

          expect(observer_policy.view_permalink?).to be false
          expect(observee_policy.view_permalink?).to be false
          expect(manager_policy.view_permalink?).to be false
          expect(random_policy.view_permalink?).to be false
        end
      end
    end
  end

  describe '#publish?' do
    context 'with draft observation' do
      let(:draft_observation) do
        build(:observation, observer: observer, company: company, published_at: nil).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
        end
      end

      it 'allows observer to publish draft' do
        policy = ObservationPolicy.new(pundit_user_observer, draft_observation)
        expect(policy.publish?).to be true
      end

      it 'denies non-observer from publishing draft' do
        observee_policy = ObservationPolicy.new(pundit_user_observee, draft_observation)
        manager_policy = ObservationPolicy.new(pundit_user_manager, draft_observation)
        random_policy = ObservationPolicy.new(pundit_user_random, draft_observation)

        expect(observee_policy.publish?).to be false
        expect(manager_policy.publish?).to be false
        expect(random_policy.publish?).to be false
      end
    end

    context 'with published observation' do
      it 'denies observer from publishing already published observation' do
        policy = ObservationPolicy.new(pundit_user_observer, observation)
        expect(policy.publish?).to be false
      end

      it 'denies non-observer from publishing already published observation' do
        observee_policy = ObservationPolicy.new(pundit_user_observee, observation)
        manager_policy = ObservationPolicy.new(pundit_user_manager, observation)
        random_policy = ObservationPolicy.new(pundit_user_random, observation)

        expect(observee_policy.publish?).to be false
        expect(manager_policy.publish?).to be false
        expect(random_policy.publish?).to be false
      end
    end
  end

  describe '#Scope' do
    let(:pundit_user_observer) { OpenStruct.new(user: observer_teammate, impersonating_teammate: nil) }
    let(:pundit_user_observee) { OpenStruct.new(user: observee_teammate, impersonating_teammate: nil) }
    let(:pundit_user_manager) { OpenStruct.new(user: manager_teammate, impersonating_teammate: nil) }
    let(:pundit_user_admin) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }
    let(:pundit_user_random) { OpenStruct.new(user: random_teammate, impersonating_teammate: nil) }

    context 'with draft observations' do
      let!(:draft_observation) do
        build(:observation, observer: observer, company: company, privacy_level: :public_to_company, published_at: nil).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
  end
end

      let!(:other_draft) do
        build(:observation, observer: observee_person, company: company, privacy_level: :public_to_company, published_at: nil).tap do |obs|
          obs.observees.build(teammate: observer_teammate)
          obs.save!
        end
      end

      it 'allows observer to see their own drafts' do
        policy_scope = ObservationPolicy::Scope.new(pundit_user_observer, Observation.all).resolve
        expect(policy_scope).to include(draft_observation)
      end

      it 'does not allow observer to see other people\'s drafts' do
        policy_scope = ObservationPolicy::Scope.new(pundit_user_observer, Observation.all).resolve
        expect(policy_scope).not_to include(other_draft)
      end

      it 'does not allow non-observers to see drafts' do
        policy_scope = ObservationPolicy::Scope.new(pundit_user_observee, Observation.all).resolve
        expect(policy_scope).not_to include(draft_observation)
        expect(policy_scope).to include(other_draft) # They can see their own draft
      end
    end

    context 'with journal observations (observer_only)' do
      let!(:journal_observation) do
        build(:observation, observer: observer, company: company, privacy_level: :observer_only).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
        end
      end

      let!(:other_journal) do
        build(:observation, observer: observee_person, company: company, privacy_level: :observer_only).tap do |obs|
          obs.observees.build(teammate: observer_teammate)
          obs.save!
          obs.publish!
        end
      end

      it 'allows observer to see their own journal entries' do
        policy_scope = ObservationPolicy::Scope.new(pundit_user_observer, Observation.all).resolve
        expect(policy_scope).to include(journal_observation)
      end

      it 'does not allow observer to see other people\'s journal entries' do
        policy_scope = ObservationPolicy::Scope.new(pundit_user_observer, Observation.all).resolve
        expect(policy_scope).not_to include(other_journal)
      end

      it 'does not allow non-observers to see journal entries' do
        policy_scope = ObservationPolicy::Scope.new(pundit_user_observee, Observation.all).resolve
        expect(policy_scope).not_to include(journal_observation)
        expect(policy_scope).to include(other_journal) # They can see their own journal
      end

      it 'does not allow managers to see journal entries even if they manage the observee' do
        policy_scope = ObservationPolicy::Scope.new(pundit_user_manager, Observation.all).resolve
        expect(policy_scope).not_to include(journal_observation)
      end

      it 'does not allow admins with can_manage_employment to see journal entries' do
        policy_scope = ObservationPolicy::Scope.new(pundit_user_admin, Observation.all).resolve
        expect(policy_scope).not_to include(journal_observation)
      end
    end

    context 'with published observations' do
      context 'observed_only privacy' do
        let!(:observed_only_obs) do
          build(:observation, observer: observer, company: company, privacy_level: :observed_only).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end

        it 'allows observer and observee to see' do
          observer_scope = ObservationPolicy::Scope.new(pundit_user_observer, Observation.all).resolve
          observee_scope = ObservationPolicy::Scope.new(pundit_user_observee, Observation.all).resolve

          expect(observer_scope).to include(observed_only_obs)
          expect(observee_scope).to include(observed_only_obs)
        end

        it 'does not allow manager to see even if they manage the observee' do
          manager_scope = ObservationPolicy::Scope.new(pundit_user_manager, Observation.all).resolve
          expect(manager_scope).not_to include(observed_only_obs)
        end

        it 'does not allow random person to see' do
          random_scope = ObservationPolicy::Scope.new(pundit_user_random, Observation.all).resolve
          expect(random_scope).not_to include(observed_only_obs)
        end
      end

      context 'managers_only privacy' do
        let!(:managers_only_obs) do
          build(:observation, observer: observer, company: company, privacy_level: :managers_only).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end

        it 'allows observer and manager to see' do
          manager_teammate.reload
          managers_only_obs.reload

          observer_scope = ObservationPolicy::Scope.new(pundit_user_observer, Observation.all).resolve
          manager_scope = ObservationPolicy::Scope.new(pundit_user_manager, Observation.all).resolve

          expect(observer_scope).to include(managers_only_obs)
          expect(manager_scope).to include(managers_only_obs)
        end

        it 'does not allow observee to see' do
          observee_scope = ObservationPolicy::Scope.new(pundit_user_observee, Observation.all).resolve
          expect(observee_scope).not_to include(managers_only_obs)
        end

        it 'does not allow random person to see' do
          random_scope = ObservationPolicy::Scope.new(pundit_user_random, Observation.all).resolve
          expect(random_scope).not_to include(managers_only_obs)
        end
      end

      context 'observed_and_managers privacy' do
        let!(:observed_and_managers_obs) do
          build(:observation, observer: observer, company: company, privacy_level: :observed_and_managers).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end

        it 'allows observer, observee, and manager to see' do
          manager_teammate.reload
          observed_and_managers_obs.reload

          observer_scope = ObservationPolicy::Scope.new(pundit_user_observer, Observation.all).resolve
          observee_scope = ObservationPolicy::Scope.new(pundit_user_observee, Observation.all).resolve
          manager_scope = ObservationPolicy::Scope.new(pundit_user_manager, Observation.all).resolve

          expect(observer_scope).to include(observed_and_managers_obs)
          expect(observee_scope).to include(observed_and_managers_obs)
          expect(manager_scope).to include(observed_and_managers_obs)
        end

        it 'does not allow random person to see' do
          random_scope = ObservationPolicy::Scope.new(pundit_user_random, Observation.all).resolve
          expect(random_scope).not_to include(observed_and_managers_obs)
        end
      end

      context 'public_to_company privacy' do
        let!(:company_public_obs) do
          build(:observation, observer: observer, company: company, privacy_level: :public_to_company).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end

        it 'allows all active company teammates to see' do
          observer_scope = ObservationPolicy::Scope.new(pundit_user_observer, Observation.all).resolve
          observee_scope = ObservationPolicy::Scope.new(pundit_user_observee, Observation.all).resolve
          manager_scope = ObservationPolicy::Scope.new(pundit_user_manager, Observation.all).resolve
          random_scope = ObservationPolicy::Scope.new(pundit_user_random, Observation.all).resolve

          expect(observer_scope).to include(company_public_obs)
          expect(observee_scope).to include(company_public_obs)
          expect(manager_scope).to include(company_public_obs)
          expect(random_scope).to include(company_public_obs)
        end

        it 'does not allow terminated teammates to see' do
          terminated_person = create(:person)
          terminated_teammate = CompanyTeammate.create!(person: terminated_person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: 1.day.ago)
          terminated_pundit_user = OpenStruct.new(user: terminated_teammate, impersonating_teammate: nil)

          terminated_scope = ObservationPolicy::Scope.new(terminated_pundit_user, Observation.all).resolve
          expect(terminated_scope).not_to include(company_public_obs)
        end

        it 'does not allow people from other companies to see' do
          other_company = create(:organization, :company)
          other_person = create(:person)
          other_teammate = CompanyTeammate.create!(person: other_person, organization: other_company)
          other_pundit_user = OpenStruct.new(user: other_teammate, impersonating_teammate: nil)

          other_scope = ObservationPolicy::Scope.new(other_pundit_user, Observation.all).resolve
          expect(other_scope).not_to include(company_public_obs)
        end
      end

      context 'public_to_world privacy' do
        let!(:public_obs) do
          build(:observation, observer: observer, company: company, privacy_level: :public_to_world).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end

        it 'allows all active company teammates to see' do
          observer_scope = ObservationPolicy::Scope.new(pundit_user_observer, Observation.all).resolve
          observee_scope = ObservationPolicy::Scope.new(pundit_user_observee, Observation.all).resolve
          manager_scope = ObservationPolicy::Scope.new(pundit_user_manager, Observation.all).resolve
          random_scope = ObservationPolicy::Scope.new(pundit_user_random, Observation.all).resolve

          expect(observer_scope).to include(public_obs)
          expect(observee_scope).to include(public_obs)
          expect(manager_scope).to include(public_obs)
          expect(random_scope).to include(public_obs)
        end

        it 'does not allow terminated teammates to see' do
          terminated_person = create(:person)
          terminated_teammate = CompanyTeammate.create!(person: terminated_person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: 1.day.ago)
          terminated_pundit_user = OpenStruct.new(user: terminated_teammate, impersonating_teammate: nil)

          terminated_scope = ObservationPolicy::Scope.new(terminated_pundit_user, Observation.all).resolve
          expect(terminated_scope).not_to include(public_obs)
        end

        it 'does not allow people from other companies to see' do
          other_company = create(:organization, :company)
          other_person = create(:person)
          other_teammate = CompanyTeammate.create!(person: other_person, organization: other_company)
          other_pundit_user = OpenStruct.new(user: other_teammate, impersonating_teammate: nil)

          other_scope = ObservationPolicy::Scope.new(other_pundit_user, Observation.all).resolve
          expect(other_scope).not_to include(public_obs)
        end
      end
    end

    context 'with admin users' do
      let!(:draft_obs) do
        build(:observation, observer: observer, company: company, privacy_level: :observer_only, published_at: nil).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
        end
      end

      let!(:journal_obs) do
        build(:observation, observer: observer, company: company, privacy_level: :observer_only).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
        end
      end

      let!(:private_obs) do
        build(:observation, observer: observer, company: company, privacy_level: :observed_only).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
        end
      end

      let(:admin_person) { create(:person, og_admin: true) }
      let(:admin_teammate) { CompanyTeammate.create!(person: admin_person, organization: company) }
      let(:admin_pundit_user) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }

      it 'allows og_admin to see all observations' do
        admin_scope = ObservationPolicy::Scope.new(admin_pundit_user, Observation.all).resolve
        expect(admin_scope).to include(draft_obs, journal_obs, private_obs)
      end
    end

    context 'when viewing_teammate is nil' do
      it 'returns empty scope' do
        policy_scope = ObservationPolicy::Scope.new(nil, Observation.all).resolve
        expect(policy_scope).to be_empty
      end
    end

    context 'with scope filtering' do
      let!(:observation_in_company) do
        build(:observation, observer: observer, company: company, privacy_level: :public_to_company).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
        end
      end

      let(:other_company) { create(:organization, :company) }
      let!(:observation_in_other_company) do
        build(:observation, observer: observer, company: other_company, privacy_level: :public_to_company).tap do |obs|
          obs.observees.build(teammate: create(:teammate, organization: other_company))
          obs.save!
          obs.publish!
        end
      end

      it 'respects existing scope filters' do
        # Filter scope to only company observations
        filtered_scope = Observation.where(company: company)
        policy_scope = ObservationPolicy::Scope.new(pundit_user_observer, filtered_scope).resolve

        expect(policy_scope).to include(observation_in_company)
        expect(policy_scope).not_to include(observation_in_other_company)
      end
    end
  end

  describe 'Comprehensive visibility matrix', :isolated do
    # Set up all the people and relationships
    # Use a unique company to avoid conflicts with outer spec
    let!(:test_company) { create(:organization, :company) }
    let(:observer_person) { create(:person) }
    let(:observee_person) { create(:person) }
    let(:manager_person) { create(:person) }
    let(:unrelated_person) { create(:person) }
    
    # Create teammates in before block to ensure they use the same test_company instance
    let(:observer_teammate) { @observer_teammate }
    let(:observee_teammate) { @observee_teammate }
    let(:manager_teammate) { @manager_teammate }
    let(:unrelated_teammate) { @unrelated_teammate }

    before do
      # Ensure test_company exists first
      company = test_company
      
      # Create all teammates with the same test_company instance, ensuring they're in the same company
      @observer_teammate = CompanyTeammate.find_or_create_by!(person: observer_person, organization: company) do |t|
        t.organization = company
      end
      @observee_teammate = CompanyTeammate.find_or_create_by!(person: observee_person, organization: company) do |t|
        t.organization = company
      end
      @manager_teammate = CompanyTeammate.find_or_create_by!(person: manager_person, organization: company) do |t|
        t.organization = company
      end
      @unrelated_teammate = CompanyTeammate.find_or_create_by!(person: unrelated_person, organization: company) do |t|
        t.organization = company
      end
      
      # Verify they're in the correct company
      [@observer_teammate, @observee_teammate, @manager_teammate, @unrelated_teammate].each do |t|
        t.reload
        unless t.organization_id == company.id
          raise "Teammate #{t.id} not in company #{company.id}, is in #{t.organization_id}"
        end
      end
      
      # Set up management hierarchy: observee reports to manager
      create(:employment_tenure, teammate: @manager_teammate, company: company)
      create(:employment_tenure, teammate: @observee_teammate, company: company, manager: manager_person)
      create(:employment_tenure, teammate: @observer_teammate, company: company)
      create(:employment_tenure, teammate: @unrelated_teammate, company: company)
      
      # Reload to clear caches
      @manager_teammate.reload
      @observee_teammate.reload
      @observer_teammate.reload
      @unrelated_teammate.reload
    end

    let(:pundit_user_observer) { OpenStruct.new(user: observer_teammate, impersonating_teammate: nil) }
    let(:pundit_user_observee) { OpenStruct.new(user: observee_teammate, impersonating_teammate: nil) }
    let(:pundit_user_manager) { OpenStruct.new(user: manager_teammate, impersonating_teammate: nil) }
    let(:pundit_user_unrelated) { OpenStruct.new(user: unrelated_teammate, impersonating_teammate: nil) }

    # Create all combinations of observations in before block to ensure teammates exist
    # 2 states (draft, published) × 6 privacy levels = 12 observations
    let(:draft_observer_only) do
      # Ensure we have the same company instance - reload to avoid caching issues
      company = Organization.find(test_company.id)
      teammate = CompanyTeammate.find(observee_teammate.id)
      
      # Verify they're in the same company
      unless teammate.organization_id == company.id
        raise "Teammate #{teammate.id} org #{teammate.organization_id} != company #{company.id}"
      end
      
      # Use create instead of build to avoid validation issues
      obs = Observation.create!(
        observer: observer_person,
        company: company,
        privacy_level: :observer_only,
        published_at: nil,
        story: 'Draft observer only',
        observed_at: Time.current
      )
      # Reload observation to ensure company is set
      obs.reload
      
      # Create observee separately - reload teammate to ensure fresh association
      teammate.reload
      Observee.create!(observation: obs, teammate: teammate)
      obs.reload
      obs
    end

    let(:draft_observed_only) do
      company = Organization.find(test_company.id)
      teammate = CompanyTeammate.find(observee_teammate.id)
      obs = Observation.create!(observer: observer_person, company: company, privacy_level: :observed_only, published_at: nil, story: 'Draft observed only', observed_at: Time.current)
      obs.reload
      teammate.reload
      Observee.create!(observation: obs, teammate: teammate)
      obs.reload
      obs
    end

    let(:draft_managers_only) do
      company = Organization.find(test_company.id)
      teammate = CompanyTeammate.find(observee_teammate.id)
      obs = Observation.create!(observer: observer_person, company: company, privacy_level: :managers_only, published_at: nil, story: 'Draft managers only', observed_at: Time.current)
      obs.reload
      teammate.reload
      Observee.create!(observation: obs, teammate: teammate)
      obs.reload
      obs
    end

    let(:draft_observed_and_managers) do
      company = Organization.find(test_company.id)
      teammate = CompanyTeammate.find(observee_teammate.id)
      obs = Observation.create!(observer: observer_person, company: company, privacy_level: :observed_and_managers, published_at: nil, story: 'Draft observed and managers', observed_at: Time.current)
      obs.reload
      teammate.reload
      Observee.create!(observation: obs, teammate: teammate)
      obs.reload
      obs
    end

    let(:draft_public_to_company) do
      company = Organization.find(test_company.id)
      teammate = CompanyTeammate.find(observee_teammate.id)
      obs = Observation.create!(observer: observer_person, company: company, privacy_level: :public_to_company, published_at: nil, story: 'Draft public to company', observed_at: Time.current)
      obs.reload
      teammate.reload
      Observee.create!(observation: obs, teammate: teammate)
      obs.reload
      obs
    end

    let(:draft_public_to_world) do
      company = Organization.find(test_company.id)
      teammate = CompanyTeammate.find(observee_teammate.id)
      obs = Observation.create!(observer: observer_person, company: company, privacy_level: :public_to_world, published_at: nil, story: 'Draft public to world', observed_at: Time.current)
      obs.reload
      teammate.reload
      Observee.create!(observation: obs, teammate: teammate)
      obs.reload
      obs
    end

    let(:published_observer_only) do
      company = Organization.find(test_company.id)
      teammate = CompanyTeammate.find(observee_teammate.id)
      obs = Observation.create!(observer: observer_person, company: company, privacy_level: :observer_only, story: 'Published observer only', observed_at: Time.current)
      obs.reload
      teammate.reload
      Observee.create!(observation: obs, teammate: teammate)
      obs.reload
      obs.publish!
      obs
    end

    let(:published_observed_only) do
      company = Organization.find(test_company.id)
      teammate = CompanyTeammate.find(observee_teammate.id)
      obs = Observation.create!(observer: observer_person, company: company, privacy_level: :observed_only, story: 'Published observed only', observed_at: Time.current)
      obs.reload
      teammate.reload
      Observee.create!(observation: obs, teammate: teammate)
      obs.reload
      obs.publish!
      obs
    end

    let(:published_managers_only) do
      company = Organization.find(test_company.id)
      teammate = CompanyTeammate.find(observee_teammate.id)
      obs = Observation.create!(observer: observer_person, company: company, privacy_level: :managers_only, story: 'Published managers only', observed_at: Time.current)
      obs.reload
      teammate.reload
      Observee.create!(observation: obs, teammate: teammate)
      obs.reload
      obs.publish!
      obs
    end

    let(:published_observed_and_managers) do
      company = Organization.find(test_company.id)
      teammate = CompanyTeammate.find(observee_teammate.id)
      obs = Observation.create!(observer: observer_person, company: company, privacy_level: :observed_and_managers, story: 'Published observed and managers', observed_at: Time.current)
      obs.reload
      teammate.reload
      Observee.create!(observation: obs, teammate: teammate)
      obs.reload
      obs.publish!
      obs
    end

    let(:published_public_to_company) do
      company = Organization.find(test_company.id)
      teammate = CompanyTeammate.find(observee_teammate.id)
      obs = Observation.create!(observer: observer_person, company: company, privacy_level: :public_to_company, story: 'Published public to company', observed_at: Time.current)
      obs.reload
      teammate.reload
      Observee.create!(observation: obs, teammate: teammate)
      obs.reload
      obs.publish!
      obs
    end

    let(:published_public_to_world) do
      company = Organization.find(test_company.id)
      teammate = CompanyTeammate.find(observee_teammate.id)
      obs = Observation.create!(observer: observer_person, company: company, privacy_level: :public_to_world, story: 'Published public to world', observed_at: Time.current)
      obs.reload
      teammate.reload
      Observee.create!(observation: obs, teammate: teammate)
      obs.reload
      obs.publish!
      obs
    end

    let(:all_observations) do
      [
        draft_observer_only,
        draft_observed_only,
        draft_managers_only,
        draft_observed_and_managers,
        draft_public_to_company,
        draft_public_to_world,
        published_observer_only,
        published_observed_only,
        published_managers_only,
        published_observed_and_managers,
        published_public_to_company,
        published_public_to_world
      ]
    end

    describe 'Scope visibility' do
      context 'when viewer is the observer' do
        it 'returns all observations they created (drafts and published)' do
          scope = ObservationPolicy::Scope.new(pundit_user_observer, Observation.all).resolve
          expect(scope.to_a).to match_array(all_observations)
        end
      end

      context 'when viewer is one of the observed' do
        it 'returns only published observations they should see based on privacy level' do
          scope = ObservationPolicy::Scope.new(pundit_user_observee, Observation.all).resolve
          expected = [
            published_observed_only,           # observed_only: observer + observees
            published_observed_and_managers,   # observed_and_managers: observer + observees + managers
            published_public_to_company,      # public_to_company: all active teammates
            published_public_to_world          # public_to_world: all active teammates
          ]
          expect(scope.to_a).to match_array(expected)
        end
      end

      context 'when viewer is the manager of one of the observed' do
        it 'returns only published observations they should see based on privacy level' do
          manager_teammate.reload
          scope = ObservationPolicy::Scope.new(pundit_user_manager, Observation.all).resolve
          expected = [
            published_managers_only,           # managers_only: observer + managers
            published_observed_and_managers,    # observed_and_managers: observer + observees + managers
            published_public_to_company,       # public_to_company: all active teammates
            published_public_to_world          # public_to_world: all active teammates
          ]
          expect(scope.to_a).to match_array(expected)
        end
      end

      context 'when viewer is unrelated (not observer, not observed, not manager)' do
        it 'returns only published public observations' do
          scope = ObservationPolicy::Scope.new(pundit_user_unrelated, Observation.all).resolve
          expected = [
            published_public_to_company,       # public_to_company: all active teammates
            published_public_to_world          # public_to_world: all active teammates
          ]
          expect(scope.to_a).to match_array(expected)
        end
      end
    end

    describe 'show? permission' do
      context 'when viewer is the observer' do
        it 'allows access to all their observations (drafts and published)' do
          all_observations.each do |obs|
            policy = ObservationPolicy.new(pundit_user_observer, obs)
            expect(policy.show?).to be(true), "Observer should see #{obs.privacy_level} #{obs.draft? ? 'draft' : 'published'}"
          end
        end
      end

      context 'when viewer is one of the observed' do
        it 'allows access only to published observations they should see' do
          # Drafts: should NOT see
          [draft_observer_only, draft_observed_only, draft_managers_only, 
           draft_observed_and_managers, draft_public_to_company, draft_public_to_world].each do |obs|
            policy = ObservationPolicy.new(pundit_user_observee, obs)
            expect(policy.show?).to be(false), "Observee should NOT see draft #{obs.privacy_level}"
          end

          # Published: should see based on privacy level
          expect(ObservationPolicy.new(pundit_user_observee, published_observer_only).show?).to be(false)
          expect(ObservationPolicy.new(pundit_user_observee, published_observed_only).show?).to be(true)
          expect(ObservationPolicy.new(pundit_user_observee, published_managers_only).show?).to be(false)
          expect(ObservationPolicy.new(pundit_user_observee, published_observed_and_managers).show?).to be(true)
          expect(ObservationPolicy.new(pundit_user_observee, published_public_to_company).show?).to be(true)
          expect(ObservationPolicy.new(pundit_user_observee, published_public_to_world).show?).to be(true)
        end
      end

      context 'when viewer is the manager of one of the observed' do
        it 'allows access only to published observations they should see' do
          manager_teammate.reload
          
          # Drafts: should NOT see
          [draft_observer_only, draft_observed_only, draft_managers_only, 
           draft_observed_and_managers, draft_public_to_company, draft_public_to_world].each do |obs|
            policy = ObservationPolicy.new(pundit_user_manager, obs)
            expect(policy.show?).to be(false), "Manager should NOT see draft #{obs.privacy_level}"
          end

          # Published: should see based on privacy level
          expect(ObservationPolicy.new(pundit_user_manager, published_observer_only).show?).to be(false)
          expect(ObservationPolicy.new(pundit_user_manager, published_observed_only).show?).to be(false)
          expect(ObservationPolicy.new(pundit_user_manager, published_managers_only).show?).to be(true)
          expect(ObservationPolicy.new(pundit_user_manager, published_observed_and_managers).show?).to be(true)
          expect(ObservationPolicy.new(pundit_user_manager, published_public_to_company).show?).to be(true)
          expect(ObservationPolicy.new(pundit_user_manager, published_public_to_world).show?).to be(true)
        end
      end

      context 'when viewer is unrelated' do
        it 'allows access only to published public observations' do
          # Drafts: should NOT see
          [draft_observer_only, draft_observed_only, draft_managers_only, 
           draft_observed_and_managers, draft_public_to_company, draft_public_to_world].each do |obs|
            policy = ObservationPolicy.new(pundit_user_unrelated, obs)
            expect(policy.show?).to be(false), "Unrelated should NOT see draft #{obs.privacy_level}"
          end

          # Published: should see only public
          expect(ObservationPolicy.new(pundit_user_unrelated, published_observer_only).show?).to be(false)
          expect(ObservationPolicy.new(pundit_user_unrelated, published_observed_only).show?).to be(false)
          expect(ObservationPolicy.new(pundit_user_unrelated, published_managers_only).show?).to be(false)
          expect(ObservationPolicy.new(pundit_user_unrelated, published_observed_and_managers).show?).to be(false)
          expect(ObservationPolicy.new(pundit_user_unrelated, published_public_to_company).show?).to be(true)
          expect(ObservationPolicy.new(pundit_user_unrelated, published_public_to_world).show?).to be(true)
        end
      end
    end

    describe 'edit? permission' do
      it 'allows only the observer to edit any observation' do
        all_observations.each do |obs|
          expect(ObservationPolicy.new(pundit_user_observer, obs).edit?).to be(true)
          expect(ObservationPolicy.new(pundit_user_observee, obs).edit?).to be(false)
          expect(ObservationPolicy.new(pundit_user_manager, obs).edit?).to be(false)
          expect(ObservationPolicy.new(pundit_user_unrelated, obs).edit?).to be(false)
        end
      end
    end

    describe 'view_permalink? permission' do
      context 'when viewer is the observer' do
        it 'allows access only to published public_to_world observations' do
          # Drafts: should NOT see (even public_to_world drafts)
          [draft_observer_only, draft_observed_only, draft_managers_only, 
           draft_observed_and_managers, draft_public_to_company, draft_public_to_world].each do |obs|
            policy = ObservationPolicy.new(pundit_user_observer, obs)
            expect(policy.view_permalink?).to be(false), "Observer should NOT see draft permalink #{obs.privacy_level}"
          end

          # Published: should see only public_to_world
          expect(ObservationPolicy.new(pundit_user_observer, published_observer_only).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_observer, published_observed_only).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_observer, published_managers_only).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_observer, published_observed_and_managers).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_observer, published_public_to_company).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_observer, published_public_to_world).view_permalink?).to be(true)
        end
      end

      context 'when viewer is one of the observed' do
        it 'allows access only to published public_to_world observations' do
          # Drafts: should NOT see
          [draft_observer_only, draft_observed_only, draft_managers_only, 
           draft_observed_and_managers, draft_public_to_company, draft_public_to_world].each do |obs|
            policy = ObservationPolicy.new(pundit_user_observee, obs)
            expect(policy.view_permalink?).to be(false), "Observee should NOT see draft permalink #{obs.privacy_level}"
          end

          # Published: should see only public_to_world
          expect(ObservationPolicy.new(pundit_user_observee, published_observer_only).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_observee, published_observed_only).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_observee, published_managers_only).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_observee, published_observed_and_managers).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_observee, published_public_to_company).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_observee, published_public_to_world).view_permalink?).to be(true)
        end
      end

      context 'when viewer is the manager of one of the observed' do
        it 'allows access only to published public_to_world observations' do
          manager_teammate.reload
          
          # Drafts: should NOT see
          [draft_observer_only, draft_observed_only, draft_managers_only, 
           draft_observed_and_managers, draft_public_to_company, draft_public_to_world].each do |obs|
            policy = ObservationPolicy.new(pundit_user_manager, obs)
            expect(policy.view_permalink?).to be(false), "Manager should NOT see draft permalink #{obs.privacy_level}"
          end

          # Published: should see only public_to_world
          expect(ObservationPolicy.new(pundit_user_manager, published_observer_only).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_manager, published_observed_only).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_manager, published_managers_only).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_manager, published_observed_and_managers).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_manager, published_public_to_company).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_manager, published_public_to_world).view_permalink?).to be(true)
        end
      end

      context 'when viewer is unrelated' do
        it 'allows access only to published public_to_world observations' do
          # Drafts: should NOT see
          [draft_observer_only, draft_observed_only, draft_managers_only, 
           draft_observed_and_managers, draft_public_to_company, draft_public_to_world].each do |obs|
            policy = ObservationPolicy.new(pundit_user_unrelated, obs)
            expect(policy.view_permalink?).to be(false), "Unrelated should NOT see draft permalink #{obs.privacy_level}"
          end

          # Published: should see only public_to_world
          expect(ObservationPolicy.new(pundit_user_unrelated, published_observer_only).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_unrelated, published_observed_only).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_unrelated, published_managers_only).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_unrelated, published_observed_and_managers).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_unrelated, published_public_to_company).view_permalink?).to be(false)
          expect(ObservationPolicy.new(pundit_user_unrelated, published_public_to_world).view_permalink?).to be(true)
        end
      end
    end
  end
end








