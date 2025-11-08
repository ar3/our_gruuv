require 'rails_helper'

RSpec.describe ObservationPolicy, type: :policy do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee_person) { create(:person) }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: company) }
  let(:manager_person) { create(:person) }
  let(:manager_teammate) { create(:teammate, person: manager_person, organization: company) }
  let(:admin_person) { create(:person) }
  let(:random_person) { create(:person) }
  let(:random_teammate) { create(:teammate, person: random_person, organization: company) }

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
      policy = ObservationPolicy.new(observer, observation)
      expect(policy.index?).to be true
    end

    it 'denies unauthenticated users' do
      policy = ObservationPolicy.new(nil, observation)
      expect(policy.index?).to be false
    end
  end

  describe '#show?' do
    it 'allows observer' do
      policy = ObservationPolicy.new(observer, observation)
      expect(policy.show?).to be true
    end

    it 'denies non-observer' do
      policy = ObservationPolicy.new(observee_person, observation)
      expect(policy.show?).to be false
    end
  end

  describe '#create?' do
    it 'allows any authenticated user' do
      policy = ObservationPolicy.new(observer, Observation.new)
      expect(policy.create?).to be true
    end

    it 'denies unauthenticated users' do
      policy = ObservationPolicy.new(nil, Observation.new)
      expect(policy.create?).to be false
    end
  end

  describe '#update?' do
    it 'allows observer' do
      policy = ObservationPolicy.new(observer, observation)
      expect(policy.update?).to be true
    end

    it 'denies non-observer' do
      policy = ObservationPolicy.new(observee_person, observation)
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
        policy = ObservationPolicy.new(observer, draft_observation)
        expect(policy.view_permalink?).to be true
      end

      it 'denies everyone else even if privacy level would allow' do
        observee_policy = ObservationPolicy.new(observee_person, draft_observation)
        manager_policy = ObservationPolicy.new(manager_person, draft_observation)
        random_policy = ObservationPolicy.new(random_person, draft_observation)

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
          policy = ObservationPolicy.new(observer, observer_only_obs)
          expect(policy.view_permalink?).to be true
        end

        it 'denies everyone else' do
          observee_policy = ObservationPolicy.new(observee_person, observer_only_obs)
          manager_policy = ObservationPolicy.new(manager_person, observer_only_obs)
          random_policy = ObservationPolicy.new(random_person, observer_only_obs)

          expect(observee_policy.view_permalink?).to be false
          expect(manager_policy.view_permalink?).to be false
          expect(random_policy.view_permalink?).to be false
        end
      end

      context 'observed_only privacy' do
        it 'allows observer and observee' do
          observer_policy = ObservationPolicy.new(observer, observation)
          observee_policy = ObservationPolicy.new(observee_person, observation)

          expect(observer_policy.view_permalink?).to be true
          expect(observee_policy.view_permalink?).to be true
        end

        it 'denies manager even if they manage the observee' do
          manager_policy = ObservationPolicy.new(manager_person, observation)
          expect(manager_policy.view_permalink?).to be false
        end

        it 'denies random person' do
          random_policy = ObservationPolicy.new(random_person, observation)
          expect(random_policy.view_permalink?).to be false
        end

        it 'denies admin even with can_manage_employment' do
          admin_policy = ObservationPolicy.new(admin_person, observation)
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
            policy = ObservationPolicy.new(observee_person, self_observation)
            expect(policy.view_permalink?).to be true
          end

          it 'denies manager from seeing employee self-observation' do
            manager_policy = ObservationPolicy.new(manager_person, self_observation)
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
          observer_policy = ObservationPolicy.new(observer, managers_only_obs)
          manager_policy = ObservationPolicy.new(manager_person, managers_only_obs)

          expect(observer_policy.view_permalink?).to be true
          expect(manager_policy.view_permalink?).to be true
        end

        it 'denies observee' do
          observee_policy = ObservationPolicy.new(observee_person, managers_only_obs)
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
          observer_policy = ObservationPolicy.new(observer, observed_and_managers_obs)
          observee_policy = ObservationPolicy.new(observee_person, observed_and_managers_obs)
          manager_policy = ObservationPolicy.new(manager_person, observed_and_managers_obs)

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
          observer_policy = ObservationPolicy.new(observer, public_obs)
          observee_policy = ObservationPolicy.new(observee_person, public_obs)
          manager_policy = ObservationPolicy.new(manager_person, public_obs)
          random_policy = ObservationPolicy.new(random_person, public_obs)

          expect(observer_policy.view_permalink?).to be true
          expect(observee_policy.view_permalink?).to be true
          expect(manager_policy.view_permalink?).to be true
          expect(random_policy.view_permalink?).to be true
        end
      end
    end
  end
end








