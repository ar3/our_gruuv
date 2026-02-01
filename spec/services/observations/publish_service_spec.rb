require 'rails_helper'

RSpec.describe Observations::PublishService do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observee_teammate) { create(:teammate, organization: company) }
  let(:ability) { create(:ability, company: company) }
  let(:assignment) { create(:assignment, company: company) }
  let(:aspiration) { create(:aspiration, company: company) }

  describe '.call' do
    context 'with a valid draft observation' do
      let(:draft) do
        obs = build(:observation, observer: observer, company: company, published_at: nil, story: 'Test story')
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs
      end

      it 'sets published_at timestamp' do
        expect {
          described_class.call(draft)
        }.to change { draft.reload.published_at }.from(nil).to(be_present)
      end

      it 'returns false when privacy level is not changed' do
        result = described_class.call(draft)
        expect(result).to be false
      end
    end

    context 'with observation ratings' do
      let(:draft) do
        obs = build(:observation, observer: observer, company: company, published_at: nil, story: 'Test story')
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs
      end

      it 'deletes all na ratings' do
        na_rating1 = create(:observation_rating, observation: draft, rateable: ability, rating: :na)
        na_rating2 = create(:observation_rating, observation: draft, rateable: assignment, rating: :na)
        
        described_class.call(draft)
        
        expect(ObservationRating.find_by(id: na_rating1.id)).to be_nil
        expect(ObservationRating.find_by(id: na_rating2.id)).to be_nil
      end

      it 'preserves positive ratings' do
        agree_rating = create(:observation_rating, observation: draft, rateable: ability, rating: :agree)
        strongly_agree_rating = create(:observation_rating, observation: draft, rateable: assignment, rating: :strongly_agree)
        
        described_class.call(draft)
        
        expect(ObservationRating.find_by(id: agree_rating.id)).to be_present
        expect(ObservationRating.find_by(id: strongly_agree_rating.id)).to be_present
      end

      it 'preserves negative ratings' do
        disagree_rating = create(:observation_rating, observation: draft, rateable: ability, rating: :disagree)
        strongly_disagree_rating = create(:observation_rating, observation: draft, rateable: assignment, rating: :strongly_disagree)
        
        described_class.call(draft)
        
        expect(ObservationRating.find_by(id: disagree_rating.id)).to be_present
        expect(ObservationRating.find_by(id: strongly_disagree_rating.id)).to be_present
      end

      it 'handles mixed ratings correctly' do
        na_rating = create(:observation_rating, observation: draft, rateable: ability, rating: :na)
        agree_rating = create(:observation_rating, observation: draft, rateable: assignment, rating: :agree)
        disagree_rating = create(:observation_rating, observation: draft, rateable: aspiration, rating: :disagree)
        
        described_class.call(draft)
        
        expect(ObservationRating.find_by(id: na_rating.id)).to be_nil
        expect(ObservationRating.find_by(id: agree_rating.id)).to be_present
        expect(ObservationRating.find_by(id: disagree_rating.id)).to be_present
      end

      it 'handles observation with only na ratings' do
        na_rating1 = create(:observation_rating, observation: draft, rateable: ability, rating: :na)
        na_rating2 = create(:observation_rating, observation: draft, rateable: assignment, rating: :na)
        
        described_class.call(draft)
        
        expect(draft.observation_ratings.count).to eq(0)
        expect(ObservationRating.find_by(id: na_rating1.id)).to be_nil
        expect(ObservationRating.find_by(id: na_rating2.id)).to be_nil
      end

      it 'handles observation with no ratings' do
        expect(draft.observation_ratings.count).to eq(0)
        
        expect {
          described_class.call(draft)
        }.not_to raise_error
        
        expect(draft.reload.published_at).to be_present
      end
    end

    context 'with privacy level enforcement' do
      context 'when observation is public and has negative ratings' do
        let(:public_draft) do
          obs = build(:observation, observer: observer, company: company, published_at: nil, 
                     story: 'Test story', privacy_level: :public_to_world)
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          create(:observation_rating, observation: obs, rateable: ability, rating: :disagree)
          obs
        end

        it 'enforces privacy level and returns true' do
          result = described_class.call(public_draft)
          
          expect(result).to be true
          expect(public_draft.reload.privacy_level).to eq('observed_and_managers')
        end
      end

      context 'when observation is public but has no negative ratings' do
        let(:public_draft) do
          obs = build(:observation, observer: observer, company: company, published_at: nil, 
                     story: 'Test story', privacy_level: :public_to_world)
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          create(:observation_rating, observation: obs, rateable: ability, rating: :agree)
          obs
        end

        it 'does not change privacy level and returns false' do
          result = described_class.call(public_draft)
          
          expect(result).to be false
          expect(public_draft.reload.privacy_level).to eq('public_to_world')
        end
      end

      context 'when observation is public_to_company and has negative ratings' do
        let(:public_draft) do
          obs = build(:observation, observer: observer, company: company, published_at: nil, 
                     story: 'Test story', privacy_level: :public_to_company)
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          create(:observation_rating, observation: obs, rateable: ability, rating: :strongly_disagree)
          obs
        end

        it 'enforces privacy level and returns true' do
          result = described_class.call(public_draft)
          
          expect(result).to be true
          expect(public_draft.reload.privacy_level).to eq('observed_and_managers')
        end
      end
    end

    context 'with validation errors' do
      let(:invalid_draft) do
        obs = build(:observation, observer: observer, company: company, published_at: nil, story: nil)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs
      end

      it 'raises ActiveRecord::RecordInvalid when story is blank' do
        expect {
          described_class.call(invalid_draft)
        }.to raise_error(ActiveRecord::RecordInvalid)
        
        expect(invalid_draft.reload.published_at).to be_nil
      end
    end

    context 'idempotency' do
      let(:draft) do
        obs = build(:observation, observer: observer, company: company, published_at: nil, story: 'Test story')
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs
      end

      it 'can be called multiple times safely' do
        # First call
        described_class.call(draft)
        first_published_at = draft.reload.published_at
        
        # Second call
        described_class.call(draft)
        second_published_at = draft.reload.published_at
        
        expect(second_published_at).to be_present
        # Both should be present, though timestamp may update
        expect(first_published_at).to be_present
        expect(second_published_at).to be_present
      end
    end
  end
end

