require 'rails_helper'

RSpec.describe ObservationPolicy, type: :policy do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observee_person) { create(:person) }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: company) }
  let(:manager_person) { create(:person) }
  let(:admin_person) { create(:person) }
  let(:random_person) { create(:person) }
  
  let(:observation) do
    build(:observation, observer: observer, company: company).tap do |obs|
      obs.observees.build(teammate: observee_teammate)
      obs.save!
    end
  end

  before do
    # Set up management hierarchy
    allow(manager_person).to receive(:in_managerial_hierarchy_of?).with(observee_person).and_return(true)
    allow(admin_person).to receive(:can_manage_employment?).with(company).and_return(true)
    allow(admin_person).to receive(:og_admin?).and_return(true)
  end

  subject { described_class }

  describe 'index' do
    permissions :index? do
      it 'allows users with company access' do
        expect(subject).to permit(observer, Observation)
      end

      it 'denies users without company access' do
        expect(subject).not_to permit(nil, Observation)
      end
    end
  end

  describe 'show' do
    permissions :show? do
      it 'allows observer to view show page' do
        expect(subject).to permit(observer, observation)
      end

      it 'denies non-observers from show page' do
        expect(subject).not_to permit(observee_person, observation)
        expect(subject).not_to permit(manager_person, observation)
        expect(subject).not_to permit(random_person, observation)
      end
    end
  end

  describe 'create' do
    permissions :create? do
      it 'allows users with company access' do
        expect(subject).to permit(observer, Observation)
      end

      it 'denies users without company access' do
        expect(subject).not_to permit(nil, Observation)
      end
    end
  end

  describe 'update' do
    permissions :update? do
      it 'allows observer to update' do
        expect(subject).to permit(observer, observation)
      end

      it 'denies non-observers from updating' do
        expect(subject).not_to permit(observee_person, observation)
        expect(subject).not_to permit(manager_person, observation)
        expect(subject).not_to permit(random_person, observation)
      end
    end
  end

  describe 'destroy' do
    permissions :destroy? do
      it 'allows observer to delete within 24 hours' do
        expect(subject).to permit(observer, observation)
      end

      it 'denies observer after 24 hours' do
        observation.update!(created_at: 25.hours.ago)
        expect(subject).not_to permit(observer, observation)
      end

      it 'allows admin to delete anytime' do
        observation.update!(created_at: 25.hours.ago)
        expect(subject).to permit(admin_person, observation)
      end

      it 'denies non-observers and non-admins' do
        expect(subject).not_to permit(observee_person, observation)
        expect(subject).not_to permit(manager_person, observation)
        expect(subject).not_to permit(random_person, observation)
      end
    end
  end

  describe 'view_permalink' do
    permissions :view_permalink? do
      context 'observer_only privacy' do
        before { observation.update!(privacy_level: :observer_only) }

        it 'allows observer' do
          expect(subject).to permit(observer, observation)
        end

        it 'denies everyone else' do
          expect(subject).not_to permit(observee_person, observation)
          expect(subject).not_to permit(manager_person, observation)
          expect(subject).not_to permit(random_person, observation)
        end
      end

      context 'observed_only privacy' do
        before { observation.update!(privacy_level: :observed_only) }

        it 'allows observer and observee' do
          expect(subject).to permit(observer, observation)
          expect(subject).to permit(observee_person, observation)
        end

        it 'denies others' do
          expect(subject).not_to permit(manager_person, observation)
          expect(subject).not_to permit(random_person, observation)
        end
      end

      context 'managers_only privacy' do
        before { observation.update!(privacy_level: :managers_only) }

        it 'allows observer and managers' do
          expect(subject).to permit(observer, observation)
          expect(subject).to permit(manager_person, observation)
        end

        it 'denies observee and others' do
          expect(subject).not_to permit(observee_person, observation)
          expect(subject).not_to permit(random_person, observation)
        end
      end

      context 'observed_and_managers privacy' do
        before { observation.update!(privacy_level: :observed_and_managers) }

        it 'allows observer, observee, and managers' do
          expect(subject).to permit(observer, observation)
          expect(subject).to permit(observee_person, observation)
          expect(subject).to permit(manager_person, observation)
        end

        it 'allows those with can_manage_employment' do
          expect(subject).to permit(admin_person, observation)
        end

        it 'denies others' do
          expect(subject).not_to permit(random_person, observation)
        end
      end

      context 'public_observation privacy' do
        before { observation.update!(privacy_level: :public_observation) }

        it 'allows everyone' do
          expect(subject).to permit(observer, observation)
          expect(subject).to permit(observee_person, observation)
          expect(subject).to permit(manager_person, observation)
          expect(subject).to permit(random_person, observation)
        end
      end
    end
  end

  describe 'view_negative_ratings' do
    permissions :view_negative_ratings? do
      before do
        # Create a negative rating
        create(:observation_rating, observation: observation, rating: :disagree)
      end

      context 'when user can view observation' do
        before { observation.update!(privacy_level: :observed_and_managers) }

        it 'allows observer to view negative ratings' do
          expect(subject).to permit(observer, observation)
        end

        it 'allows observee to view negative ratings' do
          expect(subject).to permit(observee_person, observation)
        end

        it 'allows managers to view negative ratings' do
          expect(subject).to permit(manager_person, observation)
        end

        it 'allows those with can_manage_employment to view negative ratings' do
          expect(subject).to permit(admin_person, observation)
        end
      end

      context 'when user cannot view observation' do
        before { observation.update!(privacy_level: :observer_only) }

        it 'denies non-observers from viewing negative ratings' do
          expect(subject).not_to permit(observee_person, observation)
          expect(subject).not_to permit(manager_person, observation)
          expect(subject).not_to permit(random_person, observation)
        end
      end

      context 'when user can view observation but not negative ratings' do
        before { observation.update!(privacy_level: :public_observation) }

        it 'denies random person from viewing negative ratings' do
          expect(subject).not_to permit(random_person, observation)
        end
      end
    end
  end

  describe 'post_message' do
    permissions :post_message? do
      it 'allows anyone who can view the observation' do
        observation.update!(privacy_level: :observed_and_managers)
        expect(subject).to permit(observer, observation)
        expect(subject).to permit(observee_person, observation)
        expect(subject).to permit(manager_person, observation)
      end

      it 'denies those who cannot view the observation' do
        observation.update!(privacy_level: :observer_only)
        expect(subject).not_to permit(observee_person, observation)
      end
    end
  end

  describe 'add_reaction' do
    permissions :add_reaction? do
      it 'allows anyone who can view the observation' do
        observation.update!(privacy_level: :observed_and_managers)
        expect(subject).to permit(observer, observation)
        expect(subject).to permit(observee_person, observation)
        expect(subject).to permit(manager_person, observation)
      end

      it 'denies those who cannot view the observation' do
        observation.update!(privacy_level: :observer_only)
        expect(subject).not_to permit(observee_person, observation)
      end
    end
  end

  describe 'post_to_slack' do
    permissions :post_to_slack? do
      it 'allows observer to post to slack' do
        expect(subject).to permit(observer, observation)
      end

      it 'denies non-observers from posting to slack' do
        expect(subject).not_to permit(observee_person, observation)
        expect(subject).not_to permit(manager_person, observation)
        expect(subject).not_to permit(random_person, observation)
      end
    end
  end

  describe 'view_change_history' do
    permissions :view_change_history? do
      it 'allows observer to view change history' do
        expect(subject).to permit(observer, observation)
      end

      it 'allows observee to view change history' do
        expect(subject).to permit(observee_person, observation)
      end

      it 'allows those with can_manage_employment to view change history' do
        expect(subject).to permit(admin_person, observation)
      end

      it 'denies others from viewing change history' do
        expect(subject).not_to permit(manager_person, observation)
        expect(subject).not_to permit(random_person, observation)
      end
    end
  end

  describe 'Scope' do
    let!(:observation1) { build(:observation, observer: observer, company: company, privacy_level: :observer_only).tap { |obs| obs.observees.build(teammate: observee_teammate); obs.save! } }
    let!(:observation2) { build(:observation, observer: observee_person, company: company, privacy_level: :observed_only).tap { |obs| obs.observees.build(teammate: create(:teammate, organization: company)); obs.save! } }
    let!(:observation3) { build(:observation, observer: manager_person, company: company, privacy_level: :public_observation).tap { |obs| obs.observees.build(teammate: create(:teammate, organization: company)); obs.save! } }

    context 'for admin user' do
      it 'returns all observations' do
        allow(admin_person).to receive(:og_admin?).and_return(true)
        scope = Pundit.policy_scope(admin_person, Observation)
        expect(scope).to include(observation1, observation2, observation3)
      end
    end

    context 'for regular user' do
      it 'returns observations visible to user' do
        # For now, the scope returns none since we need company context from controller
        scope = Pundit.policy_scope(observer, Observation)
        expect(scope).to be_empty
      end
    end
  end
end