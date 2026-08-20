require 'rails_helper'

RSpec.describe Observations::EnsureCompanyAspirationsService, type: :service do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observation) do
    Observation.create!(
      observer: observer,
      company: company,
      story: 'Test',
      privacy_level: :observed_only,
      observed_at: Time.current
    )
  end
  let!(:company_aspiration) { create(:aspiration, company: company, name: 'Integrity') }
  let!(:dept_aspiration) { create(:aspiration, :with_department, company: company, name: 'Dept Value') }

  describe '#call' do
    it 'adds missing root company aspirations as na' do
      described_class.new(observation: observation).call

      rating = observation.observation_ratings.find_by(rateable: company_aspiration)
      expect(rating).to be_present
      expect(rating.rating).to eq('na')
      expect(observation.observation_ratings.exists?(rateable: dept_aspiration)).to be false
    end

    it 'does not reset an already-scored company aspiration' do
      create(:observation_rating, observation: observation, rateable: company_aspiration, rating: :agree)

      described_class.new(observation: observation).call

      expect(observation.observation_ratings.find_by(rateable: company_aspiration).rating).to eq('agree')
    end

    it 'does not remove existing aspiration ratings' do
      create(:observation_rating, observation: observation, rateable: dept_aspiration, rating: :na)

      described_class.new(observation: observation).call

      expect(observation.observation_ratings.exists?(rateable: dept_aspiration)).to be true
      expect(observation.observation_ratings.exists?(rateable: company_aspiration)).to be true
    end

    context 'when observation is not persisted' do
      let(:unsaved) do
        Observation.new(
          observer: observer,
          company: company,
          story: 'Draft',
          privacy_level: :observed_only,
          observed_at: Time.current
        )
      end

      it 'builds company aspiration ratings in memory' do
        described_class.new(observation: unsaved).call

        aspiration_ids = unsaved.observation_ratings.select { |r| r.rateable_type == 'Aspiration' }.map(&:rateable_id)
        expect(aspiration_ids).to contain_exactly(company_aspiration.id)
      end
    end
  end
end
