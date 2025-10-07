require 'rails_helper'

RSpec.describe ObservationVisibilityQuery, type: :query do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observee_person) { create(:person) }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: company) }
  let(:manager_person) { create(:person) }
  let(:admin_person) { create(:person) }
  let(:random_person) { create(:person) }

  let!(:observation1) { build(:observation, observer: observer, company: company, privacy_level: :observer_only).tap { |obs| obs.observees.build(teammate: observee_teammate); obs.save! } }
  let!(:observation2) { build(:observation, observer: observee_person, company: company, privacy_level: :observed_only).tap { |obs| obs.observees.build(teammate: create(:teammate, organization: company)); obs.save! } }
  let!(:observation3) { build(:observation, observer: manager_person, company: company, privacy_level: :managers_only).tap { |obs| obs.observees.build(teammate: observee_teammate); obs.save! } }
  let!(:observation4) { build(:observation, observer: observer, company: company, privacy_level: :observed_and_managers).tap { |obs| obs.observees.build(teammate: observee_teammate); obs.save! } }
  let!(:observation5) { build(:observation, observer: random_person, company: company, privacy_level: :public_observation).tap { |obs| obs.observees.build(teammate: create(:teammate, organization: company)); obs.save! } }

  before do
    # Set up management hierarchy
    allow(manager_person).to receive(:in_managerial_hierarchy_of?).with(observee_person).and_return(true)
    allow(admin_person).to receive(:can_manage_employment?).and_return(true)
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
    end

    context 'for observee' do
      let(:query) { described_class.new(observee_person, company) }

      it 'returns observations where they are observed' do
        results = query.visible_observations
        expect(results).to include(observation1, observation3, observation4)
      end

      it 'returns public observations' do
        results = query.visible_observations
        expect(results).to include(observation5)
      end

      it 'does not return private observations from others' do
        results = query.visible_observations
        expect(results).not_to include(observation2)
      end
    end

    context 'for manager' do
      let(:query) { described_class.new(manager_person, company) }

      it 'returns observations they created' do
        results = query.visible_observations
        expect(results).to include(observation3)
      end

      it 'returns observations about people they manage' do
        results = query.visible_observations
        expect(results).to include(observation1, observation4)
      end

      it 'returns public observations' do
        results = query.visible_observations
        expect(results).to include(observation5)
      end

      it 'does not return private observations from others' do
        results = query.visible_observations
        expect(results).not_to include(observation2)
      end
    end

    context 'for admin with can_manage_employment' do
      let(:query) { described_class.new(admin_person, company) }

      it 'returns all observations in company' do
        results = query.visible_observations
        expect(results).to include(observation1, observation2, observation3, observation4, observation5)
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
      let(:observed_only_obs) { build(:observation, observer: observer, company: company, privacy_level: :observed_only).tap { |obs| obs.observees.build(teammate: observee_teammate); obs.save! } }

      it 'allows observer and observee' do
        observer_query = described_class.new(observer, company)
        observee_query = described_class.new(observee_person, company)
        
        expect(observer_query.visible_to?(observed_only_obs)).to be true
        expect(observee_query.visible_to?(observed_only_obs)).to be true
      end

      it 'denies others' do
        manager_query = described_class.new(manager_person, company)
        expect(manager_query.visible_to?(observed_only_obs)).to be false
      end
    end

    context 'managers_only privacy' do
      it 'allows observer and managers' do
        observer_query = described_class.new(observer, company)
        manager_query = described_class.new(manager_person, company)
        
        expect(observer_query.visible_to?(observation3)).to be true
        expect(manager_query.visible_to?(observation3)).to be true
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

      it 'allows those with can_manage_employment' do
        admin_query = described_class.new(admin_person, company)
        expect(admin_query.visible_to?(observation4)).to be true
      end
    end

    context 'public_observation privacy' do
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
        expect(query.can_view_negative_ratings?(observation1)).to be true
        expect(query.can_view_negative_ratings?(observation4)).to be true
      end

      it 'allows managers to view negative ratings' do
        query = described_class.new(manager_person, company)
        expect(query.can_view_negative_ratings?(observation1)).to be true
        expect(query.can_view_negative_ratings?(observation4)).to be true
      end

      it 'allows those with can_manage_employment to view negative ratings' do
        query = described_class.new(admin_person, company)
        expect(query.can_view_negative_ratings?(observation1)).to be true
        expect(query.can_view_negative_ratings?(observation4)).to be true
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
        expect(query.can_view_negative_ratings?(observation5)).to be false
      end
    end
  end
end
