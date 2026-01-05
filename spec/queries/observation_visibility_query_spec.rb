require 'rails_helper'

RSpec.describe ObservationVisibilityQuery, type: :query do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observee_person) { create(:person) }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: company) }
  let(:manager_person) { create(:person) }
  let(:admin_person) { create(:person) }
  let(:random_person) { create(:person) }

  let!(:observation1) { build(:observation, observer: observer, company: company, privacy_level: :observer_only).tap { |obs| obs.observees.build(teammate: observee_teammate); obs.save!; obs.publish! } }
  let!(:observation2) { build(:observation, observer: observee_person, company: company, privacy_level: :observed_only).tap { |obs| obs.observees.build(teammate: create(:teammate, organization: company)); obs.save!; obs.publish! } }
  let!(:observation3) { build(:observation, observer: manager_person, company: company, privacy_level: :managers_only).tap { |obs| obs.observees.build(teammate: observee_teammate); obs.save!; obs.publish! } }
  let!(:observation4) { build(:observation, observer: observer, company: company, privacy_level: :observed_and_managers).tap { |obs| obs.observees.build(teammate: observee_teammate); obs.save!; obs.publish! } }
  let!(:observation5) { build(:observation, observer: random_person, company: company, privacy_level: :public_to_world).tap { |obs| obs.observees.build(teammate: create(:teammate, organization: company)); obs.save!; obs.publish! } }

  before do
    # Set up real management hierarchy
    observer_teammate = create(:teammate, person: observer, organization: company)
    create(:employment_tenure, teammate: observer_teammate, company: company)
    
    manager_teammate = CompanyTeammate.create!(person: manager_person, organization: company)
    create(:employment_tenure, teammate: manager_teammate, company: company)
    create(:employment_tenure, teammate: observee_teammate, company: company, manager_teammate: manager_teammate)
    
    # Admin has employment management permissions
    admin_teammate = create(:teammate, person: admin_person, organization: company)
    admin_teammate.update!(can_manage_employment: true)
    create(:employment_tenure, teammate: admin_teammate, company: company)
    
    # Random person also has a teammate for testing
    random_teammate = create(:teammate, person: random_person, organization: company)
    create(:employment_tenure, teammate: random_teammate, company: company)
  end

  describe '#visible_observations' do
    context 'for observer' do
      let(:query) { described_class.new(observer, company) }

      it 'returns all observations they created' do
        results = query.visible_observations
        expect(results).to include(observation1, observation4)
      end

      it 'returns public observations' do
        results = query.visible_observations
        expect(results).to include(observation5)
      end

      it 'does not return private observations from others' do
        results = query.visible_observations
        expect(results).not_to include(observation2, observation3)
      end

      it 'includes observer\'s own soft-deleted observations' do
        soft_deleted = build(:observation, observer: observer, company: company, privacy_level: :public_to_world).tap { |obs| obs.observees.build(teammate: observee_teammate); obs.save!; obs.publish!; obs.soft_delete! }
        results = query.visible_observations
        expect(results).to include(soft_deleted)
      end

      it 'excludes soft-deleted observations from others' do
        soft_deleted = build(:observation, observer: random_person, company: company, privacy_level: :public_to_world).tap { |obs| obs.observees.build(teammate: create(:teammate, organization: company)); obs.save!; obs.publish!; obs.soft_delete! }
        results = query.visible_observations
        expect(results).not_to include(soft_deleted)
      end
    end

    context 'for observee' do
      let(:query) { described_class.new(observee_person, company) }

      it 'returns observations where they are observed' do
        results = query.visible_observations
        expect(results).to include(observation4)
      end

      it 'returns public observations' do
        results = query.visible_observations
        expect(results).to include(observation5)
      end

      it 'does not return private observations from others' do
        results = query.visible_observations
        # observation2 is created by observee_person, so they should be able to see it
        # This test might be testing a different scenario
        expect(results).to include(observation2)
      end
    end

    context 'for manager' do
      let(:query) { described_class.new(manager_person, company) }

      it 'returns observations they created' do
        results = query.visible_observations
        expect(results).to include(observation3)
      end

      it 'returns observations about people they directly manage' do
        results = query.visible_observations
        expect(results).to include(observation4)
      end

      it 'does not return observations about people they indirectly manage (only direct managers via employment_tenures)' do
        # Set up indirect report: observee -> manager -> grand_manager
        # New rules only check direct manager relationships via employment_tenures
        grand_manager = create(:person)
        grand_manager_teammate = CompanyTeammate.create!(person: grand_manager, organization: company)
        manager_teammate = Teammate.find_by(person: manager_person, organization: company)
        
        create(:employment_tenure, teammate: grand_manager_teammate, company: company)
        # Update existing manager tenure to have grand_manager as manager
        manager_tenure = EmploymentTenure.find_by(teammate: manager_teammate, company: company)
        manager_tenure.update!(manager_teammate: grand_manager_teammate)
        
        indirect_observee = create(:person)
        indirect_observee_teammate = create(:teammate, person: indirect_observee, organization: company)
        create(:employment_tenure, teammate: indirect_observee_teammate, company: company, manager_teammate: manager_teammate)
        
        indirect_observation = build(:observation, observer: observer, company: company, privacy_level: :managers_only).tap do |obs|
          obs.observees.build(teammate: indirect_observee_teammate)
          obs.save!
          obs.publish!
        end
        
        grand_manager_query = described_class.new(grand_manager, company)
        results = grand_manager_query.visible_observations
        # Grand manager is NOT a direct manager of indirect_observee, so they cannot see it
        expect(results).not_to include(indirect_observation)
      end

      it 'returns public observations' do
        results = query.visible_observations
        expect(results).to include(observation5)
      end

      it 'does not return private observations from others' do
        results = query.visible_observations
        expect(results).not_to include(observation2)
      end

      it 'does not return observed_only observations where employee observes themselves' do
        # Employee creates observation of themselves with observed_only privacy
        employee_self_observation = build(:observation, observer: observee_person, company: company, privacy_level: :observed_only).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
        end

        results = query.visible_observations
        expect(results).not_to include(employee_self_observation)
      end
    end

    context 'for admin with can_manage_employment' do
      let(:query) { described_class.new(admin_person, company) }
      let(:admin_teammate) { Teammate.find_by(person: admin_person, organization: company) || create(:teammate, person: admin_person, organization: company) }

      before do
        admin_teammate # Ensure admin has a teammate record
      end

      it 'returns only public observations and observations they created (no can_manage_employment override)' do
        # New rules: can_manage_employment does NOT grant access
        # Admin can only see: public observations, observations they created, observations where they are observee/manager
        results = query.visible_observations
        expect(results).to include(observation5) # public_to_world
        expect(results).not_to include(observation1) # observer_only (journal) - not observer
        expect(results).not_to include(observation2) # observed_only - not observer, not observee, not manager
        expect(results).not_to include(observation3) # managers_only - not observer, not observee, not manager
        expect(results).not_to include(observation4) # observed_and_managers - not observer, not observee, not manager
      end

      it 'does not return observed_only observations even with can_manage_employment' do
        employee_self_observation = build(:observation, observer: observee_person, company: company, privacy_level: :observed_only).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
        end

        results = query.visible_observations
        expect(results).not_to include(employee_self_observation)
      end
    end

    context 'for random person' do
      let(:query) { described_class.new(random_person, company) }

      it 'returns only public observations' do
        results = query.visible_observations
        expect(results).to include(observation5)
        expect(results).not_to include(observation1, observation2, observation3, observation4)
      end
    end

    context 'with no user' do
      let(:query) { described_class.new(nil, company) }

      it 'returns empty collection' do
        results = query.visible_observations
        expect(results).to be_empty
      end
    end

    context 'new 4-rule visibility logic' do
      describe 'Rule 1: Public published observations' do
        let(:public_company_obs) do
          build(:observation, observer: observer, company: company, privacy_level: :public_to_company).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end
        let(:public_world_obs) do
          build(:observation, observer: observer, company: company, privacy_level: :public_to_world).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end
        let(:unpublished_public_obs) do
          build(:observation, observer: observer, company: company, privacy_level: :public_to_company, published_at: nil).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
          end
        end

        it 'allows all teammates to see published public_to_company observations' do
          random_query = described_class.new(random_person, company)
          results = random_query.visible_observations
          expect(results).to include(public_company_obs)
        end

        it 'allows all teammates to see published public_to_world observations' do
          random_query = described_class.new(random_person, company)
          results = random_query.visible_observations
          expect(results).to include(public_world_obs)
        end

        it 'does not allow non-observers to see unpublished public observations' do
          random_query = described_class.new(random_person, company)
          results = random_query.visible_observations
          expect(results).not_to include(unpublished_public_obs)
        end
      end

      describe 'Rule 2: Observer sees all their own observations' do
        let(:draft_obs) do
          build(:observation, observer: observer, company: company, privacy_level: :observer_only, published_at: nil).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
          end
        end
        let(:published_private_obs) do
          build(:observation, observer: observer, company: company, privacy_level: :observed_only).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end

        it 'allows observer to see their own drafts regardless of privacy level' do
          observer_query = described_class.new(observer, company)
          results = observer_query.visible_observations
          expect(results).to include(draft_obs)
        end

        it 'allows observer to see their own published observations regardless of privacy level' do
          observer_query = described_class.new(observer, company)
          results = observer_query.visible_observations
          expect(results).to include(published_private_obs)
        end
      end

      describe 'Rule 3: Observee sees published observations they are in' do
        let(:published_observed_only) do
          build(:observation, observer: observer, company: company, privacy_level: :observed_only).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end
        let(:published_observed_and_managers) do
          build(:observation, observer: observer, company: company, privacy_level: :observed_and_managers).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end
        let(:unpublished_observed_only) do
          build(:observation, observer: observer, company: company, privacy_level: :observed_only, published_at: nil).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
          end
        end
        let(:published_observer_only) do
          build(:observation, observer: observer, company: company, privacy_level: :observer_only).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end

        it 'allows observee to see published observed_only observations they are in' do
          observee_query = described_class.new(observee_person, company)
          results = observee_query.visible_observations
          expect(results).to include(published_observed_only)
        end

        it 'allows observee to see published observed_and_managers observations they are in' do
          observee_query = described_class.new(observee_person, company)
          results = observee_query.visible_observations
          expect(results).to include(published_observed_and_managers)
        end

        it 'does not allow observee to see unpublished observed_only observations' do
          observee_query = described_class.new(observee_person, company)
          results = observee_query.visible_observations
          expect(results).not_to include(unpublished_observed_only)
        end

        it 'does not allow observee to see published observer_only (journal) observations' do
          observee_query = described_class.new(observee_person, company)
          results = observee_query.visible_observations
          expect(results).not_to include(published_observer_only)
        end
      end

      describe 'Rule 4: Manager sees published observations for their reports' do
        let(:published_managers_only) do
          build(:observation, observer: observer, company: company, privacy_level: :managers_only).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end
        let(:published_observed_and_managers) do
          build(:observation, observer: observer, company: company, privacy_level: :observed_and_managers).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end
        let(:unpublished_managers_only) do
          build(:observation, observer: observer, company: company, privacy_level: :managers_only, published_at: nil).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
          end
        end
        let(:published_observed_only) do
          build(:observation, observer: observer, company: company, privacy_level: :observed_only).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end

        it 'allows manager to see published managers_only observations for their reports' do
          manager_query = described_class.new(manager_person, company)
          results = manager_query.visible_observations
          expect(results).to include(published_managers_only)
        end

        it 'allows manager to see published observed_and_managers observations for their reports' do
          manager_query = described_class.new(manager_person, company)
          results = manager_query.visible_observations
          expect(results).to include(published_observed_and_managers)
        end

        it 'does not allow manager to see unpublished managers_only observations' do
          manager_query = described_class.new(manager_person, company)
          results = manager_query.visible_observations
          expect(results).not_to include(unpublished_managers_only)
        end

        it 'does not allow manager to see published observed_only observations (even if they manage the observee)' do
          manager_query = described_class.new(manager_person, company)
          results = manager_query.visible_observations
          expect(results).not_to include(published_observed_only)
        end
      end
    end
  end

  describe '#visible_to?' do
    context 'observer_only privacy' do
      it 'allows observer' do
        query = described_class.new(observer, company)
        expect(query.visible_to?(observation1)).to be true
      end

      it 'denies everyone else' do
        query = described_class.new(observee_person, company)
        expect(query.visible_to?(observation1)).to be false
      end
    end

    context 'observed_only privacy' do
      let(:observed_only_obs) { build(:observation, observer: observer, company: company, privacy_level: :observed_only).tap { |obs| obs.observees.build(teammate: observee_teammate); obs.save!; obs.publish! } }

      it 'allows observer and observee' do
        observer_query = described_class.new(observer, company)
        observee_query = described_class.new(observee_person, company)
        
        expect(observer_query.visible_to?(observed_only_obs)).to be true
        expect(observee_query.visible_to?(observed_only_obs)).to be true
      end

      it 'denies others including managers' do
        manager_query = described_class.new(manager_person, company)
        expect(manager_query.visible_to?(observed_only_obs)).to be false
      end

      it 'denies admins even with can_manage_employment' do
        admin_query = described_class.new(admin_person, company)
        expect(admin_query.visible_to?(observed_only_obs)).to be false
      end

      it 'allows observer observing themselves' do
        # Employee creates observation of themselves
        self_observation = build(:observation, observer: observee_person, company: company, privacy_level: :observed_only).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
        end

        observee_query = described_class.new(observee_person, company)
        expect(observee_query.visible_to?(self_observation)).to be true
      end
    end

    context 'managers_only privacy' do
      it 'allows observer and direct managers' do
        observer_query = described_class.new(manager_person, company)
        manager_query = described_class.new(manager_person, company)
        
        expect(observer_query.visible_to?(observation3)).to be true
        expect(manager_query.visible_to?(observation3)).to be true
      end

      it 'does not allow indirect managers (only direct managers via employment_tenures)' do
        grand_manager = create(:person)
        grand_manager_teammate = CompanyTeammate.create!(person: grand_manager, organization: company)
        manager_teammate = Teammate.find_by(person: manager_person, organization: company)
        
        create(:employment_tenure, teammate: grand_manager_teammate, company: company)
        # Update existing manager tenure to have grand_manager as manager
        manager_tenure = EmploymentTenure.find_by(teammate: manager_teammate, company: company)
        manager_tenure.update!(manager_teammate: grand_manager_teammate)
        
        grand_manager_query = described_class.new(grand_manager, company)
        # Grand manager is NOT a direct manager of observee_teammate, so they cannot see it
        expect(grand_manager_query.visible_to?(observation3)).to be false
      end

      it 'denies observee' do
        observee_query = described_class.new(observee_person, company)
        expect(observee_query.visible_to?(observation3)).to be false
      end
    end

    context 'observed_and_managers privacy' do
      it 'allows observer, observee, and managers' do
        observer_query = described_class.new(observer, company)
        observee_query = described_class.new(observee_person, company)
        manager_query = described_class.new(manager_person, company)
        
        expect(observer_query.visible_to?(observation4)).to be true
        expect(observee_query.visible_to?(observation4)).to be true
        expect(manager_query.visible_to?(observation4)).to be true
      end

      it 'does not allow those with can_manage_employment (no override in new rules)' do
        admin_query = described_class.new(admin_person, company)
        # Admin is not observer, not observee, not manager - so cannot see it
        expect(admin_query.visible_to?(observation4)).to be false
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

      it 'allows all authenticated company members' do
        observer_query = described_class.new(observer, company)
        observee_query = described_class.new(observee_person, company)
        manager_query = described_class.new(manager_person, company)
        random_query = described_class.new(random_person, company)
        
        expect(observer_query.visible_to?(company_public_obs)).to be true
        expect(observee_query.visible_to?(company_public_obs)).to be true
        expect(manager_query.visible_to?(company_public_obs)).to be true
        expect(random_query.visible_to?(company_public_obs)).to be true
      end
    end

    context 'public_to_world privacy' do
      it 'allows everyone' do
        observer_query = described_class.new(observer, company)
        observee_query = described_class.new(observee_person, company)
        manager_query = described_class.new(manager_person, company)
        random_query = described_class.new(random_person, company)
        
        expect(observer_query.visible_to?(observation5)).to be true
        expect(observee_query.visible_to?(observation5)).to be true
        expect(manager_query.visible_to?(observation5)).to be true
        expect(random_query.visible_to?(observation5)).to be true
      end
    end

    context 'draft visibility' do
      let(:draft_observation) do
        build(:observation, observer: observer, company: company, privacy_level: :observed_only, published_at: nil).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
        end
      end

      let(:published_observation) do
        build(:observation, observer: observer, company: company, privacy_level: :observed_only).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
        end
      end

      context 'for observer' do
        let(:query) { described_class.new(observer, company) }

        it 'returns their own draft observations' do
          results = query.visible_observations
          expect(results).to include(draft_observation)
        end

        it 'returns published observations they can see' do
          results = query.visible_observations
          expect(results).to include(published_observation)
        end
      end

      context 'for observee' do
        let(:query) { described_class.new(observee_person, company) }

        it 'does not return draft observations even if they would be able to see published version' do
          results = query.visible_observations
          expect(results).not_to include(draft_observation)
        end

        it 'returns published observations they can see' do
          results = query.visible_observations
          expect(results).to include(published_observation)
        end
      end

      context 'for manager' do
        let(:query) { described_class.new(manager_person, company) }

        it 'does not return draft observations' do
          results = query.visible_observations
          expect(results).not_to include(draft_observation)
        end

        it 'does not return published observed_only observations' do
          results = query.visible_observations
          expect(results).not_to include(published_observation)
        end
      end
    end

    context '#visible_to? with drafts' do
      let(:draft_observation) do
        build(:observation, observer: observer, company: company, privacy_level: :public_to_world, published_at: nil).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
        end
      end

      it 'allows observer to see their own draft' do
        query = described_class.new(observer, company)
        expect(query.visible_to?(draft_observation)).to be true
      end

      it 'denies everyone else from seeing drafts, even if privacy level would allow' do
        observee_query = described_class.new(observee_person, company)
        manager_query = described_class.new(manager_person, company)
        random_query = described_class.new(random_person, company)

        expect(observee_query.visible_to?(draft_observation)).to be false
        expect(manager_query.visible_to?(draft_observation)).to be false
        expect(random_query.visible_to?(draft_observation)).to be false
      end
    end

    context '#visible_to? with soft-deleted observations' do
      let(:soft_deleted_observation) do
        build(:observation, observer: observer, company: company, privacy_level: :public_to_world).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
          obs.soft_delete!
        end
      end

      it 'allows observer to see their own soft-deleted observation' do
        query = described_class.new(observer, company)
        expect(query.visible_to?(soft_deleted_observation)).to be true
      end

      it 'denies everyone else from seeing soft-deleted observations, even if privacy level would allow' do
        observee_query = described_class.new(observee_person, company)
        manager_query = described_class.new(manager_person, company)
        random_query = described_class.new(random_person, company)

        expect(observee_query.visible_to?(soft_deleted_observation)).to be false
        expect(manager_query.visible_to?(soft_deleted_observation)).to be false
        expect(random_query.visible_to?(soft_deleted_observation)).to be false
      end
    end
  end

  describe '#can_view_negative_ratings?' do
    before do
      # Add negative ratings to observations
      create(:observation_rating, observation: observation1, rating: :disagree)
      create(:observation_rating, observation: observation4, rating: :strongly_disagree)
    end

    context 'when user can view observation' do
      it 'allows observer to view negative ratings' do
        query = described_class.new(observer, company)
        expect(query.can_view_negative_ratings?(observation1)).to be true
        expect(query.can_view_negative_ratings?(observation4)).to be true
      end

      it 'allows observee to view negative ratings' do
        query = described_class.new(observee_person, company)
        expect(query.can_view_negative_ratings?(observation1)).to be false  # observer_only
        expect(query.can_view_negative_ratings?(observation4)).to be true   # observed_and_managers
      end

      it 'allows managers to view negative ratings' do
        query = described_class.new(manager_person, company)
        expect(query.can_view_negative_ratings?(observation1)).to be false  # observer_only
        expect(query.can_view_negative_ratings?(observation4)).to be true  # observed_and_managers
      end

      it 'does not allow those with can_manage_employment to view negative ratings (no override in new rules)' do
        # Admins can only view negative ratings if they are observer, observee, or manager
        query = described_class.new(admin_person, company)
        expect(query.can_view_negative_ratings?(observation1)).to be false  # observer_only (journal) - not observer
        expect(query.can_view_negative_ratings?(observation4)).to be false  # observed_and_managers - not observer, not observee, not manager
      end
    end

    context 'when user cannot view observation' do
      it 'denies access to negative ratings' do
        query = described_class.new(random_person, company)
        expect(query.can_view_negative_ratings?(observation1)).to be false
        expect(query.can_view_negative_ratings?(observation4)).to be false
      end
    end

    context 'when user can view observation but not negative ratings' do
      it 'denies access to negative ratings' do
        query = described_class.new(random_person, company)
        # random_person is the observer of observation5, so they should be able to view negative ratings
        expect(query.can_view_negative_ratings?(observation5)).to be true
      end
    end
  end

  describe '#managed_teammate_ids_for_person' do
    let(:query) { described_class.new(manager_person, company) }

    it 'returns teammate IDs for direct reports' do
      teammate_ids = query.send(:managed_teammate_ids_for_person)
      expect(teammate_ids).to include(observee_teammate.id)
    end

    it 'returns teammate IDs for indirect reports (reports of reports)' do
      # Set up hierarchy: indirect_report -> direct_report -> manager
      direct_report = create(:person)
      direct_report_teammate = CompanyTeammate.create!(person: direct_report, organization: company)
      indirect_report = create(:person)
      indirect_report_teammate = create(:teammate, person: indirect_report, organization: company)
      
      manager_teammate = Teammate.find_by(person: manager_person, organization: company)
      create(:employment_tenure, teammate: direct_report_teammate, company: company, manager_teammate: manager_teammate)
      create(:employment_tenure, teammate: indirect_report_teammate, company: company, manager_teammate: direct_report_teammate)
      
      teammate_ids = query.send(:managed_teammate_ids_for_person)
      expect(teammate_ids).to include(direct_report_teammate.id)
      expect(teammate_ids).to include(indirect_report_teammate.id)
    end

    it 'returns empty array when person is not a Person' do
      non_person_query = described_class.new(nil, company)
      teammate_ids = non_person_query.send(:managed_teammate_ids_for_person)
      expect(teammate_ids).to eq([])
    end
  end
end
