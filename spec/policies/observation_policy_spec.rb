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

  let(:pundit_user_observer) { OpenStruct.new(user: observer_teammate, real_user: observer_teammate) }
  let(:pundit_user_observee) { OpenStruct.new(user: observee_teammate, real_user: observee_teammate) }
  let(:pundit_user_manager) { OpenStruct.new(user: manager_teammate, real_user: manager_teammate) }
  let(:pundit_user_admin) { OpenStruct.new(user: admin_teammate, real_user: admin_teammate) }
  let(:pundit_user_random) { OpenStruct.new(user: random_teammate, real_user: random_teammate) }

  let(:observation) do
    build(:observation, observer: observer, company: company, privacy_level: :observed_only).tap do |obs|
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs.publish!
    end
  end

  before do
    allow(manager_person).to receive(:in_managerial_hierarchy_of?).and_return(false)
    allow(manager_person).to receive(:in_managerial_hierarchy_of?).with(observee_person, company).and_return(true)
    allow(admin_person).to receive(:can_manage_employment?).and_return(true)
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
    it 'allows observer' do
      policy = ObservationPolicy.new(pundit_user_observer, observation)
      expect(policy.show?).to be true
    end

    it 'denies non-observer' do
      policy = ObservationPolicy.new(pundit_user_observee, observation)
      expect(policy.show?).to be false
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
        build(:observation, observer: observer, company: company, privacy_level: :public_observation, published_at: nil).tap do |obs|
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

        it 'allows observer and manager' do
          observer_policy = ObservationPolicy.new(pundit_user_observer, managers_only_obs)
          manager_policy = ObservationPolicy.new(pundit_user_manager, managers_only_obs)

          expect(observer_policy.view_permalink?).to be true
          expect(manager_policy.view_permalink?).to be true
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

        it 'allows observer, observee, and manager' do
          observer_policy = ObservationPolicy.new(pundit_user_observer, observed_and_managers_obs)
          observee_policy = ObservationPolicy.new(pundit_user_observee, observed_and_managers_obs)
          manager_policy = ObservationPolicy.new(pundit_user_manager, observed_and_managers_obs)

          expect(observer_policy.view_permalink?).to be true
          expect(observee_policy.view_permalink?).to be true
          expect(manager_policy.view_permalink?).to be true
        end
      end

      context 'public_observation privacy' do
        let(:public_obs) do
          build(:observation, observer: observer, company: company, privacy_level: :public_observation).tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
            obs.publish!
          end
        end

        it 'allows everyone' do
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








