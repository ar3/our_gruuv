require 'rails_helper'

RSpec.describe ObservationRating, type: :model do
  let(:company) { create(:organization, :company) }
  let(:observation) { build(:observation, company: company).tap { |obs| obs.observees.build(teammate: create(:teammate, organization: company)); obs.save! } }
  let(:ability) { create(:ability, organization: company) }
  let(:assignment) { create(:assignment, company: company) }
  let(:aspiration) { create(:aspiration, organization: company) }

  let(:observation_rating) do
    build(:observation_rating, observation: observation, rateable: ability, rating: :agree)
  end

  describe 'associations' do
    it { should belong_to(:observation) }
    it { should belong_to(:rateable) }
  end

  describe 'enums' do
    it 'defines rating enum with descriptive values' do
      expect(ObservationRating.ratings).to eq({
        'strongly_disagree' => 'strongly_disagree',
        'disagree' => 'disagree',
        'na' => 'na',
        'agree' => 'agree',
        'strongly_agree' => 'strongly_agree'
      })
    end
  end

  describe 'validations' do
    it { should validate_presence_of(:observation) }
    it { should validate_presence_of(:rateable) }
    it { should validate_presence_of(:rating) }
    it { should validate_inclusion_of(:rateable_type).in_array(%w[Ability Assignment Aspiration]) }
    
    it 'validates uniqueness of rateable_id scoped to observation_id and rateable_type' do
      observation_rating.save!
      duplicate_rating = build(:observation_rating, observation: observation, rateable: ability, rating: :disagree)
      expect(duplicate_rating).not_to be_valid
      expect(duplicate_rating.errors[:rateable_id]).to include('has already been taken')
    end

    it 'validates unique rating per observation and rateable' do
      observation_rating.save!
      
      duplicate_rating = build(:observation_rating, observation: observation, rateable: ability, rating: :disagree)
      expect(duplicate_rating).not_to be_valid
      expect(duplicate_rating.errors[:rateable_id]).to include('has already been taken')
    end

    it 'allows same rateable for different observations' do
      observation_rating.save!
      
      other_observation = build(:observation, company: company).tap { |obs| obs.observees.build(teammate: create(:teammate, organization: company)); obs.save! }
      other_rating = build(:observation_rating, observation: other_observation, rateable: ability, rating: :disagree)
      expect(other_rating).to be_valid
    end
  end

  describe 'scopes' do
    let!(:positive_rating1) { create(:observation_rating, observation: observation, rateable: ability, rating: :strongly_agree) }
    let!(:positive_rating2) { create(:observation_rating, observation: observation, rateable: assignment, rating: :agree) }
    let!(:negative_rating1) { create(:observation_rating, observation: observation, rateable: aspiration, rating: :disagree) }
    let!(:negative_rating2) { create(:observation_rating, observation: observation, rateable: create(:ability, organization: company), rating: :strongly_disagree) }
    let!(:neutral_rating) { create(:observation_rating, observation: observation, rateable: create(:assignment, company: company), rating: :na) }

    describe '.positive' do
      it 'returns strongly_agree and agree ratings' do
        expect(ObservationRating.positive).to include(positive_rating1, positive_rating2)
        expect(ObservationRating.positive).not_to include(negative_rating1, negative_rating2, neutral_rating)
      end
    end

    describe '.negative' do
      it 'returns disagree and strongly_disagree ratings' do
        expect(ObservationRating.negative).to include(negative_rating1, negative_rating2)
        expect(ObservationRating.negative).not_to include(positive_rating1, positive_rating2, neutral_rating)
      end
    end

    describe '.neutral' do
      it 'returns na ratings' do
        expect(ObservationRating.neutral).to include(neutral_rating)
        expect(ObservationRating.neutral).not_to include(positive_rating1, positive_rating2, negative_rating1, negative_rating2)
      end
    end

    describe '.for_rateable' do
      it 'returns ratings for specific rateable' do
        expect(ObservationRating.for_rateable(ability)).to include(positive_rating1)
        expect(ObservationRating.for_rateable(ability)).not_to include(positive_rating2, negative_rating1, negative_rating2, neutral_rating)
      end
    end

    describe '.by_rating' do
      it 'returns ratings with specific rating value' do
        expect(ObservationRating.by_rating(:agree)).to include(positive_rating2)
        expect(ObservationRating.by_rating(:agree)).not_to include(positive_rating1, negative_rating1, negative_rating2, neutral_rating)
      end
    end
  end

  describe 'rating type methods' do
    describe '#positive?' do
      it 'returns true for strongly_agree' do
        observation_rating.rating = :strongly_agree
        expect(observation_rating.positive?).to be true
      end

      it 'returns true for agree' do
        observation_rating.rating = :agree
        expect(observation_rating.positive?).to be true
      end

      it 'returns false for other ratings' do
        observation_rating.rating = :disagree
        expect(observation_rating.positive?).to be false
      end
    end

    describe '#negative?' do
      it 'returns true for disagree' do
        observation_rating.rating = :disagree
        expect(observation_rating.negative?).to be true
      end

      it 'returns true for strongly_disagree' do
        observation_rating.rating = :strongly_disagree
        expect(observation_rating.negative?).to be true
      end

      it 'returns false for other ratings' do
        observation_rating.rating = :agree
        expect(observation_rating.negative?).to be false
      end
    end

    describe '#neutral?' do
      it 'returns true for na' do
        observation_rating.rating = :na
        expect(observation_rating.neutral?).to be true
      end

      it 'returns false for other ratings' do
        observation_rating.rating = :agree
        expect(observation_rating.neutral?).to be false
      end
    end
  end

  describe 'polymorphic associations' do
    it 'works with Ability' do
      rating = build(:observation_rating, observation: observation, rateable: ability)
      expect(rating.rateable).to eq(ability)
      expect(rating.rateable_type).to eq('Ability')
    end

    it 'works with Assignment' do
      rating = build(:observation_rating, observation: observation, rateable: assignment)
      expect(rating.rateable).to eq(assignment)
      expect(rating.rateable_type).to eq('Assignment')
    end

    it 'works with Aspiration' do
      rating = build(:observation_rating, observation: observation, rateable: aspiration)
      expect(rating.rateable).to eq(aspiration)
      expect(rating.rateable_type).to eq('Aspiration')
    end
  end

  describe 'factory' do
    it 'creates valid observation rating' do
      expect(observation_rating).to be_valid
    end

    it 'saves successfully' do
      expect { observation_rating.save! }.not_to raise_error
    end
  end
end