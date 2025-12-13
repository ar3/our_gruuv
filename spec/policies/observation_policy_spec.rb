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

  describe '#index?' do
    it 'allows any authenticated user' do
      policy = ObservationPolicy.new(pundit_user_observer, observation)
      expect(policy.index?).to be true
    end

    it 'denies unauthenticated users' do
      policy = ObservationPolicy.new(nil, observation)
      expect(policy.index?).to be false
    end
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

      it 'allows observer' do
        policy = ObservationPolicy.new(pundit_user_observer, draft_observation)
        expect(policy.view_permalink?).to be true
      end

      it 'denies everyone else even if privacy level would allow' do
        observee_policy = ObservationPolicy.new(pundit_user_observee, draft_observation)
        manager_policy = ObservationPolicy.new(pundit_user_manager, draft_observation)
        random_policy = ObservationPolicy.new(pundit_user_random, draft_observation)

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

        it 'allows observer' do
          policy = ObservationPolicy.new(pundit_user_observer, observer_only_obs)
          expect(policy.view_permalink?).to be true
        end

        it 'denies everyone else' do
          observee_policy = ObservationPolicy.new(pundit_user_observee, observer_only_obs)
          manager_policy = ObservationPolicy.new(pundit_user_manager, observer_only_obs)
          random_policy = ObservationPolicy.new(pundit_user_random, observer_only_obs)

          expect(observee_policy.view_permalink?).to be false
          expect(manager_policy.view_permalink?).to be false
          expect(random_policy.view_permalink?).to be false
        end
      end

      context 'observed_only privacy' do
        it 'allows observer and observee' do
          observer_policy = ObservationPolicy.new(pundit_user_observer, observation)
          observee_policy = ObservationPolicy.new(pundit_user_observee, observation)

          expect(observer_policy.view_permalink?).to be true
          expect(observee_policy.view_permalink?).to be true
        end

        it 'denies manager even if they manage the observee' do
          manager_policy = ObservationPolicy.new(pundit_user_manager, observation)
          expect(manager_policy.view_permalink?).to be false
        end

        it 'denies random person' do
          random_policy = ObservationPolicy.new(pundit_user_random, observation)
          expect(random_policy.view_permalink?).to be false
        end

        it 'denies admin even with can_manage_employment' do
          admin_policy = ObservationPolicy.new(pundit_user_admin, observation)
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

          it 'allows employee to see their own self-observation' do
            policy = ObservationPolicy.new(pundit_user_observee, self_observation)
            expect(policy.view_permalink?).to be true
          end

          it 'denies manager from seeing employee self-observation' do
            manager_policy = ObservationPolicy.new(pundit_user_manager, self_observation)
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

        it 'allows observer and direct manager' do
          # Reload manager_teammate to ensure fresh data
          manager_teammate.reload
          # Reload the observation to ensure all associations are fresh
          managers_only_obs.reload
          
          observer_policy = ObservationPolicy.new(pundit_user_observer, managers_only_obs)
          manager_policy = ObservationPolicy.new(pundit_user_manager, managers_only_obs)

          expect(observer_policy.view_permalink?).to be true
          expect(manager_policy.view_permalink?).to be true
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
          managers_only_obs.reload
          
          grand_manager_policy = ObservationPolicy.new(grand_manager_pundit_user, managers_only_obs)
          expect(grand_manager_policy.view_permalink?).to be true
        end

        it 'denies observee' do
          observee_policy = ObservationPolicy.new(pundit_user_observee, managers_only_obs)
          expect(observee_policy.view_permalink?).to be false
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

          expect(observer_policy.view_permalink?).to be true
          expect(observee_policy.view_permalink?).to be true
          expect(manager_policy.view_permalink?).to be true
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
          expect(grand_manager_policy.view_permalink?).to be true
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
end








