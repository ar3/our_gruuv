require 'rails_helper'

RSpec.describe ObservationsQuery, type: :query do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee_person) { create(:person) }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: company) }
  let(:manager_person) { create(:person) }
  let(:manager_teammate) { create(:teammate, person: manager_person, organization: company) }

  let!(:observation1) do
    build(:observation, observer: observer, company: company, privacy_level: :observer_only, observed_at: 1.week.ago).tap do |obs|
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs.publish!
    end
  end

  let!(:observation2) do
    build(:observation, observer: observee_person, company: company, privacy_level: :observed_only, observed_at: 2.days.ago).tap do |obs|
      obs.observees.build(teammate: observee_teammate) # Employee observes themselves
      obs.save!
      obs.publish!
    end
  end

  let!(:observation3) do
    build(:observation, observer: observer, company: company, privacy_level: :public_observation, observed_at: 1.day.ago).tap do |obs|
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs.publish!
    end
  end

  let!(:draft_observation) do
    build(:observation, observer: observer, company: company, privacy_level: :public_observation, published_at: nil).tap do |obs|
      obs.observees.build(teammate: observee_teammate)
      obs.save!
    end
  end

  before do
    allow(manager_person).to receive(:in_managerial_hierarchy_of?).and_return(false)
    allow(manager_person).to receive(:in_managerial_hierarchy_of?).with(observee_person, company).and_return(true)
  end

  describe '#call' do
    context 'for observer' do
      let(:query) { described_class.new(company, {}, current_person: observer) }

      it 'returns all observations they can see' do
        results = query.call.to_a
        expect(results).to include(observation1, observation3)
        expect(results).not_to include(observation2) # observed_only self-observation from someone else
        expect(results).to include(draft_observation) # Their own draft
      end
    end

    context 'for observee' do
      let(:query) { described_class.new(company, {}, current_person: observee_person) }

      it 'returns observations they can see' do
        results = query.call.to_a
        expect(results).to include(observation2) # Their own self-observation
        expect(results).to include(observation3) # Public observation
        expect(results).not_to include(observation1) # observer_only from someone else
        expect(results).not_to include(draft_observation) # Draft from someone else
      end
    end

    context 'for manager' do
      let(:query) { described_class.new(company, {}, current_person: manager_person) }

      it 'does not return observed_only observations where employee observes themselves' do
        results = query.call.to_a
        expect(results).not_to include(observation2) # Employee self-observation with observed_only
        expect(results).to include(observation3) # Public observation
      end
    end
  end

  describe 'filtering' do
    let(:query) { described_class.new(company, params, current_person: observer) }

    context 'by privacy level' do
      let(:params) { { privacy: ['observer_only'] } }

      it 'filters to specified privacy levels' do
        results = query.call.to_a
        expect(results).to include(observation1)
        expect(results).not_to include(observation3)
      end
    end

    context 'by timeframe' do
      let(:params) { { timeframe: 'this_week' } }

      it 'filters to observations in timeframe' do
        results = query.call.to_a
        expect(results).to include(observation3) # 1 day ago
        expect(results).not_to include(observation1) # 1 week ago
      end
    end

    context 'by multiple privacy levels' do
      let(:params) { { privacy: ['observer_only', 'public_observation'] } }

      it 'returns observations matching any of the privacy levels' do
        results = query.call.to_a
        expect(results).to include(observation1, observation3)
        expect(results).not_to include(observation2)
      end
    end
  end

  describe 'sorting' do
    let(:query) { described_class.new(company, params, current_person: observer) }

    context 'by observed_at_desc (default)' do
      let(:params) { {} }

      it 'sorts by most recent first' do
        results = query.call.to_a
        expect(results.first).to eq(observation3) # 1 day ago
        expect(results.second).to eq(observation1) # 1 week ago
      end
    end

    context 'by observed_at_asc' do
      let(:params) { { sort: 'observed_at_asc' } }

      it 'sorts by oldest first' do
        results = query.call.to_a
        expect(results.first).to eq(observation1) # 1 week ago
        expect(results.last).to eq(observation3) # 1 day ago
      end
    end

    context 'by ratings_count_desc' do
      let!(:observation_with_rating) do
        build(:observation, observer: observer, company: company, privacy_level: :public_observation).tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
          create(:observation_rating, observation: obs)
          create(:observation_rating, observation: obs)
        end
      end

      let(:params) { { sort: 'ratings_count_desc' } }

      it 'sorts by observations with most ratings first' do
        results = query.call.to_a
        expect(results.first).to eq(observation_with_rating)
      end
    end

    context 'by story_asc' do
      let(:params) { { sort: 'story_asc' } }

      it 'sorts alphabetically by story' do
        observation1.update!(story: 'A story')
        observation3.update!(story: 'Z story')

        results = query.call.to_a
        expect(results.first).to eq(observation1)
        expect(results.last).to eq(observation3)
      end
    end
  end

  describe 'current_filters' do
    it 'returns active filters' do
      query = described_class.new(company, { privacy: ['observer_only'], timeframe: 'this_week' }, current_person: observer)
      expect(query.current_filters).to eq({ privacy: ['observer_only'], timeframe: 'this_week' })
    end

    it 'excludes all timeframe' do
      query = described_class.new(company, { timeframe: 'all' }, current_person: observer)
      expect(query.current_filters).to eq({})
    end
  end

  describe 'current_sort' do
    it 'returns default sort when none specified' do
      query = described_class.new(company, {}, current_person: observer)
      expect(query.current_sort).to eq('observed_at_desc')
    end

    it 'returns specified sort' do
      query = described_class.new(company, { sort: 'story_asc' }, current_person: observer)
      expect(query.current_sort).to eq('story_asc')
    end
  end

  describe 'current_view' do
    it 'returns default view when none specified' do
      query = described_class.new(company, {}, current_person: observer)
      expect(query.current_view).to eq('table')
    end

    it 'returns specified view' do
      query = described_class.new(company, { view: 'cards' }, current_person: observer)
      expect(query.current_view).to eq('cards')
    end

    it 'supports viewStyle parameter' do
      query = described_class.new(company, { viewStyle: 'list' }, current_person: observer)
      expect(query.current_view).to eq('list')
    end
  end

  describe 'has_active_filters?' do
    it 'returns true when filters are active' do
      query = described_class.new(company, { privacy: ['observer_only'] }, current_person: observer)
      expect(query.has_active_filters?).to be true
    end

    it 'returns false when no filters are active' do
      query = described_class.new(company, {}, current_person: observer)
      expect(query.has_active_filters?).to be false
    end
  end

  describe 'draft visibility' do
    it 'does not leak draft observations to unauthorized users' do
      query = described_class.new(company, {}, current_person: observee_person)
      results = query.call.to_a
      expect(results).not_to include(draft_observation)
    end

    it 'includes draft observations for creator' do
      query = described_class.new(company, {}, current_person: observer)
      results = query.call.to_a
      expect(results).to include(draft_observation)
    end
  end
end

