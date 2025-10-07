require 'rails_helper'

RSpec.describe ObservationRatingDecorator, type: :decorator do
  let(:company) { create(:organization, :company) }
  let(:observation) { build(:observation, company: company).tap { |obs| obs.observees.build(teammate: create(:teammate, organization: company)); obs.save! } }
  let(:ability) { create(:ability, organization: company) }
  let(:observation_rating) do
    build(:observation_rating, observation: observation, rateable: ability, rating: :agree)
  end
  let(:decorated_rating) { observation_rating.decorate }

  describe '#rating_to_words' do
    it 'returns correct words for each rating' do
      observation_rating.rating = :strongly_agree
      expect(decorated_rating.rating_to_words).to eq('Exceptional')
      
      observation_rating.rating = :agree
      expect(decorated_rating.rating_to_words).to eq('Good')
      
      observation_rating.rating = :na
      expect(decorated_rating.rating_to_words).to eq('N/A')
      
      observation_rating.rating = :disagree
      expect(decorated_rating.rating_to_words).to eq('Opportunity')
      
      observation_rating.rating = :strongly_disagree
      expect(decorated_rating.rating_to_words).to eq('Major Concern')
    end
  end

  describe '#rating_icon' do
    it 'returns correct icons for each rating' do
      observation_rating.rating = :strongly_agree
      expect(decorated_rating.rating_icon).to eq('⭐')
      
      observation_rating.rating = :agree
      expect(decorated_rating.rating_icon).to eq('👍')
      
      observation_rating.rating = :na
      expect(decorated_rating.rating_icon).to eq('👁️‍🗨️')
      
      observation_rating.rating = :disagree
      expect(decorated_rating.rating_icon).to eq('👎')
      
      observation_rating.rating = :strongly_disagree
      expect(decorated_rating.rating_icon).to eq('⭕')
    end
  end

  describe '#rating_color_class' do
    it 'returns correct CSS classes for each rating' do
      observation_rating.rating = :strongly_agree
      expect(decorated_rating.rating_color_class).to eq('text-success')
      
      observation_rating.rating = :agree
      expect(decorated_rating.rating_color_class).to eq('text-primary')
      
      observation_rating.rating = :na
      expect(decorated_rating.rating_color_class).to eq('text-muted')
      
      observation_rating.rating = :disagree
      expect(decorated_rating.rating_color_class).to eq('text-warning')
      
      observation_rating.rating = :strongly_disagree
      expect(decorated_rating.rating_color_class).to eq('text-danger')
    end
  end

  describe '#descriptive_text' do
    it 'returns descriptive text with rateable name' do
      observation_rating.rating = :strongly_agree
      expect(decorated_rating.descriptive_text).to eq("Exceptional display of #{ability.name}")
    end
  end

  describe '#to_descriptive_html' do
    it 'returns HTML formatted descriptive text' do
      observation_rating.rating = :strongly_agree
      expected_html = "<strong>Exceptional</strong> display of <strong>#{ability.name}</strong>"
      expect(decorated_rating.to_descriptive_html).to eq(expected_html)
    end
  end
end
