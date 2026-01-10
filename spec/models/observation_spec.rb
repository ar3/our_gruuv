require 'rails_helper'

RSpec.describe Observation, type: :model do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:teammate1) { create(:teammate, organization: company) }
  let(:teammate2) { create(:teammate, organization: company) }
  let(:ability) { create(:ability, organization: company) }
  let(:assignment) { create(:assignment, company: company) }
  let(:aspiration) { create(:aspiration, organization: company) }

  let(:observation) do
    build(:observation,
          observer: observer,
          company: company,
          story: 'Great work on the project!',
          primary_feeling: 'happy',
          privacy_level: :observed_only)
  end

  # Helper method to save observation with observees
  def save_observation_with_observees(obs = observation)
    obs.observees.build(teammate: teammate1)
    obs.save!
    obs
  end

  describe 'associations' do
    it { should belong_to(:observer).class_name('Person') }
    it { should belong_to(:company).class_name('Organization') }
    it { should belong_to(:observation_trigger).optional }
    it { should belong_to(:observable_moment).optional }
    it { should have_many(:observees).dependent(:destroy) }
    it { should have_many(:observed_teammates).through(:observees).source(:teammate) }
    it { should have_many(:observation_ratings).dependent(:destroy) }
    it { should have_many(:abilities).through(:observation_ratings).source(:rateable) }
    it { should have_many(:assignments).through(:observation_ratings).source(:rateable) }
    it { should have_many(:aspirations).through(:observation_ratings).source(:rateable) }
    it { should have_many(:notifications).dependent(:destroy) }
  end

  describe 'enums' do
    it 'defines privacy_level enum with descriptive values' do
      expect(Observation.privacy_levels).to eq({
        'observer_only' => 'observer_only',
        'observed_only' => 'observed_only', 
        'managers_only' => 'managers_only',
        'observed_and_managers' => 'observed_and_managers',
        'public_to_company' => 'public_to_company',
        'public_to_world' => 'public_to_world'
      })
    end
  end

  describe 'validations' do
    it { should validate_presence_of(:observer) }
    it { should validate_presence_of(:company) }
    it 'validates story presence only when published' do
      draft = build(:observation, published_at: nil, story: '', observer: observer, company: company)
      draft.observees.build(teammate: teammate1)
      expect(draft).to be_valid
      
      published = build(:observation, published_at: Time.current, story: '', observer: observer, company: company)
      published.observees.build(teammate: teammate1)
      expect(published).not_to be_valid
      expect(published.errors[:story]).to include("can't be blank")
    end
    it { should validate_presence_of(:privacy_level) }
    
    it 'validates primary_feeling inclusion when present' do
      observation.primary_feeling = 'invalid_feeling'
      expect(observation).not_to be_valid
      expect(observation.errors[:primary_feeling]).to include('is not included in the list')
    end
    
    it 'allows primary_feeling to be nil' do
      observation.primary_feeling = nil
      save_observation_with_observees(observation)
      expect(observation).to be_valid
    end
    
    it 'validates secondary_feeling inclusion when present' do
      observation.secondary_feeling = 'invalid_feeling'
      expect(observation).not_to be_valid
      expect(observation.errors[:secondary_feeling]).to include('is not included in the list')
    end
    it 'validates custom_slug uniqueness' do
      observation.custom_slug = 'test-slug'
      save_observation_with_observees(observation)
      
      duplicate_observation = build(:observation, 
                                   observer: observer, 
                                   company: company, 
                                   custom_slug: 'test-slug')
      duplicate_observation.observees.build(teammate: teammate1)
      
      expect(duplicate_observation).not_to be_valid
      expect(duplicate_observation.errors[:custom_slug]).to include('has already been taken')
    end

    it 'validates primary_feeling is from Feelings constant' do
      observation.primary_feeling = 'invalid_feeling'
      expect(observation).not_to be_valid
      expect(observation.errors[:primary_feeling]).to include('is not included in the list')
    end

    it 'validates secondary_feeling is from Feelings constant when present' do
      observation.secondary_feeling = 'invalid_feeling'
      expect(observation).not_to be_valid
      expect(observation.errors[:secondary_feeling]).to include('is not included in the list')
    end

    it 'allows nil secondary_feeling' do
      observation.secondary_feeling = nil
      observation.observees.build(teammate: teammate1)
      expect(observation).to be_valid
    end

    it 'validates observer and observees are in same company' do
      other_company = create(:organization, :company)
      other_teammate = create(:teammate, organization: other_company)
      
      observation.observees.build(teammate: other_teammate)
      expect(observation).not_to be_valid
      expect(observation.errors[:observees]).to include('must be in the same company as the observer')
    end
    
    it 'allows moment-based observations to bypass company validation' do
      observable_moment = create(:observable_moment, :new_hire, company: company)
      other_company = create(:organization, :company)
      other_teammate = create(:teammate, organization: other_company)
      
      # Create a new observation with observable_moment_id set from the start
      # Use a fresh observation instance to avoid any caching issues
      moment_observation = Observation.new(
        observer: observer,
        company: company,
        story: 'Test story',
        primary_feeling: 'happy',
        privacy_level: :observed_only,
        observable_moment_id: observable_moment.id
      )
      moment_observation.observees.build(teammate: other_teammate)
      
      # Should be valid because observable_moment_id provides context
      expect(moment_observation.observable_moment_id).to be_present
      expect(moment_observation).to be_valid
    end
  end

  describe 'scopes' do
    let!(:observation1) { build(:observation, company: company, observed_at: 1.day.ago).tap { |obs| obs.observees.build(teammate: teammate1); obs.save! } }
    let!(:observation2) { build(:observation, company: company, observed_at: 2.days.ago).tap { |obs| obs.observees.build(teammate: teammate1); obs.save! } }
    let!(:observation3) { build(:observation, company: company, privacy_level: :observer_only).tap { |obs| obs.observees.build(teammate: teammate1); obs.save! } }

    describe '.recent' do
    it 'orders by observed_at desc' do
      # Only check the two observations we created with specific observed_at values
      recent_observations = Observation.where(id: [observation1.id, observation2.id]).recent
      expect(recent_observations.pluck(:id)).to eq([observation1.id, observation2.id])
    end
    end

    describe '.journal' do
      it 'returns observer_only observations' do
        expect(Observation.journal).to include(observation3)
        expect(Observation.journal).not_to include(observation1, observation2)
      end
    end

    describe '.for_company' do
      it 'returns observations for specific company' do
        other_company = create(:organization, :company)
        other_observation = build(:observation, company: other_company).tap { |obs| obs.observees.build(teammate: create(:teammate, organization: other_company)); obs.save! }
        
        expect(Observation.for_company(company)).to include(observation1, observation2, observation3)
        expect(Observation.for_company(company)).not_to include(other_observation)
      end
    end

    describe '.by_feeling' do
      it 'returns observations with specific feeling' do
        observation1.update!(primary_feeling: 'happy')
        observation2.update!(primary_feeling: 'lonely')
        
        expect(Observation.by_feeling('happy')).to include(observation1)
        expect(Observation.by_feeling('happy')).not_to include(observation2)
        expect(Observation.by_feeling('lonely')).to include(observation2)
      end
    end
    
    describe '.with_observable_moments' do
      it 'returns observations with observable moments' do
        observable_moment = create(:observable_moment, :new_hire, company: company)
        moment_observation = create(:observation, observable_moment: observable_moment, observer: observer, company: company)
        moment_observation.observees.build(teammate: teammate1)
        moment_observation.save!
        
        expect(Observation.with_observable_moments).to include(moment_observation)
        expect(Observation.with_observable_moments).not_to include(observation1, observation2)
      end
    end
    
    describe '.without_observable_moments' do
      it 'returns observations without observable moments' do
        observable_moment = create(:observable_moment, :new_hire, company: company)
        moment_observation = create(:observation, observable_moment: observable_moment, observer: observer, company: company)
        moment_observation.observees.build(teammate: teammate1)
        moment_observation.save!
        
        expect(Observation.without_observable_moments).to include(observation1, observation2)
        expect(Observation.without_observable_moments).not_to include(moment_observation)
      end
    end
    
    describe '.for_moment_type' do
      it 'returns observations for specific moment type' do
        new_hire_moment = create(:observable_moment, :new_hire, company: company)
        seat_change_moment = create(:observable_moment, :seat_change, company: company)
        
        new_hire_obs = build(:observation, observable_moment: new_hire_moment, observer: observer, company: company, story: 'New hire story')
        new_hire_obs.observees.build(teammate: teammate1)
        new_hire_obs.save!
        
        seat_change_obs = build(:observation, observable_moment: seat_change_moment, observer: observer, company: company, story: 'Seat change story')
        seat_change_obs.observees.build(teammate: teammate1)
        seat_change_obs.save!
        
        expect(Observation.for_moment_type('new_hire')).to include(new_hire_obs)
        expect(Observation.for_moment_type('new_hire')).not_to include(seat_change_obs)
        expect(Observation.for_moment_type('seat_change')).to include(seat_change_obs)
        expect(Observation.for_moment_type('seat_change')).not_to include(new_hire_obs)
      end
    end
  end

  describe 'permalink methods' do
    before do
      observation.observed_at = Time.parse('2025-10-05 14:30:00')
      save_observation_with_observees(observation)
    end

    describe '#permalink_id' do
      it 'returns date-id format without slug' do
        date_part = observation.observed_at.strftime('%Y-%m-%d')
        expect(observation.permalink_id).to eq("#{date_part}-#{observation.id}")
      end
      
      it 'includes custom slug when present' do
        observation.custom_slug = 'awesome-work'
        date_part = observation.observed_at.strftime('%Y-%m-%d')
        expect(observation.permalink_id).to eq("#{date_part}-#{observation.id}-awesome-work")
      end
    end
    
    describe '.find_by_permalink_id' do
      it 'finds observation by permalink_id without slug' do
        permalink_id = observation.permalink_id
        found_observation = Observation.find_by_permalink_id(permalink_id)
        expect(found_observation).to eq(observation)
      end
      
      it 'finds observation by permalink_id with slug' do
        observation.custom_slug = 'great-job'
        permalink_id = observation.permalink_id
        found_observation = Observation.find_by_permalink_id(permalink_id)
        expect(found_observation).to eq(observation)
      end
      
      it 'returns nil for invalid permalink_id' do
        expect(Observation.find_by_permalink_id('invalid')).to be_nil
        expect(Observation.find_by_permalink_id('2025-10-05')).to be_nil
        expect(Observation.find_by_permalink_id('2025-10-05-999')).to be_nil
      end
    end
  end

  describe '#feelings_display' do
    it 'displays primary feeling only' do
      observation.primary_feeling = 'happy'
      observation.secondary_feeling = nil
      expect(observation.feelings_display).to eq('😀 (Happy)')
    end

    it 'displays both primary and secondary feelings' do
      observation.primary_feeling = 'happy'
      observation.secondary_feeling = 'inspired'
      expect(observation.feelings_display).to eq('😀 (Happy) and 🤩 (Inspired)')
    end

    it 'handles nil primary feeling gracefully' do
      observation.primary_feeling = nil
      observation.secondary_feeling = nil
      expect(observation.feelings_display).to eq('')
    end
  end

  describe 'rating methods' do
    before do
      save_observation_with_observees(observation)
      
      create(:observation_rating, observation: observation, rateable: ability, rating: :strongly_agree)
      create(:observation_rating, observation: observation, rateable: assignment, rating: :disagree)
    end

    describe '#positive_ratings' do
      it 'returns positive ratings' do
        expect(observation.positive_ratings.count).to eq(1)
        expect(observation.positive_ratings.first.rateable).to eq(ability)
      end
    end

    describe '#negative_ratings' do
      it 'returns negative ratings' do
        expect(observation.negative_ratings.count).to eq(1)
        expect(observation.negative_ratings.first.rateable).to eq(assignment)
      end
    end

    describe '#has_negative_ratings?' do
      it 'returns true when negative ratings exist' do
        expect(observation.has_negative_ratings?).to be true
      end

      it 'returns false when no negative ratings exist' do
        observation.observation_ratings.negative.destroy_all
        expect(observation.has_negative_ratings?).to be false
      end
    end
  end

  describe 'soft delete methods' do
    before do
      save_observation_with_observees(observation)
    end

    describe '#soft_delete!' do
      it 'sets deleted_at timestamp' do
        observation.soft_delete!
        expect(observation.deleted_at).to be_present
      end
    end

    describe '#soft_deleted?' do
      it 'returns true when deleted_at is present' do
        observation.update!(deleted_at: Time.current)
        expect(observation.soft_deleted?).to be true
      end

      it 'returns false when deleted_at is nil' do
        expect(observation.soft_deleted?).to be false
      end
    end

    describe '#restore!' do
      it 'clears deleted_at timestamp' do
        observation.update!(deleted_at: Time.current)
        observation.restore!
        expect(observation.deleted_at).to be_nil
      end
    end
  end

  describe 'soft delete methods' do
    before { save_observation_with_observees(observation) }

    describe '#soft_delete!' do
      it 'sets deleted_at timestamp' do
        observation.soft_delete!
        expect(observation.deleted_at).to be_present
      end
    end

    describe '#soft_deleted?' do
      it 'returns true when deleted_at is present' do
        observation.update!(deleted_at: Time.current)
        expect(observation.soft_deleted?).to be true
      end

      it 'returns false when deleted_at is nil' do
        expect(observation.soft_deleted?).to be false
      end
    end

    describe '#restore!' do
      it 'clears deleted_at timestamp' do
        observation.update!(deleted_at: Time.current)
        observation.restore!
        expect(observation.deleted_at).to be_nil
      end
    end
  end

  describe 'observable moment processing' do
    let(:observer_teammate) { CompanyTeammate.find_or_create_by!(person: observer, organization: company) }
    let(:observable_moment) { create(:observable_moment, :new_hire, company: company, primary_observer_person: observer) }
    
    describe 'AssociateAndProcessService integration' do
      it 'marks moment as processed immediately when associated' do
        observation.observees.build(teammate: teammate1)
        observation.save!
        
        expect(observable_moment.reload.processed?).to be false
        
        ObservableMoments::AssociateAndProcessService.call(
          observation: observation,
          observable_moment_id: observable_moment.id
        )
        
        expect(observation.reload.observable_moment).to eq(observable_moment)
        expect(observable_moment.reload.processed?).to be true
        expect(observable_moment.processed_by_teammate).to eq(observer_teammate)
        expect(observable_moment.processed_at).to be_present
        expect(observable_moment.processed_by_teammate.person).to eq(observer)
      end
      
      it 'does not process moment if already processed' do
        observation.observees.build(teammate: teammate1)
        observation.save!
        
        original_processed_at = 1.hour.ago
        observable_moment.update!(processed_at: original_processed_at, processed_by_teammate: observer_teammate)
        
        ObservableMoments::AssociateAndProcessService.call(
          observation: observation,
          observable_moment_id: observable_moment.id
        )
        
        expect(observable_moment.reload.processed_at).to be_within(1.second).of(original_processed_at)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_validation' do
      it 'sets observed_at default' do
        observation.observed_at = nil
        observation.valid?
        expect(observation.observed_at).to be_present
      end
    end
  end

  describe 'scopes' do
    describe '.soft_deleted' do
      it 'returns only soft-deleted observations' do
        obs1 = save_observation_with_observees
        obs2 = save_observation_with_observees(build(:observation, observer: observer, company: company))
        obs1.soft_delete!
        
        expect(Observation.soft_deleted).to include(obs1)
        expect(Observation.soft_deleted).not_to include(obs2)
      end
    end

    describe '.not_soft_deleted' do
      it 'returns only non-soft-deleted observations' do
        obs1 = save_observation_with_observees
        obs2 = save_observation_with_observees(build(:observation, observer: observer, company: company))
        obs1.soft_delete!
        
        expect(Observation.not_soft_deleted).not_to include(obs1)
        expect(Observation.not_soft_deleted).to include(obs2)
      end
    end
  end
end
