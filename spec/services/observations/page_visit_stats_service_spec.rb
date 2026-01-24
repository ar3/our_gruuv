require 'rails_helper'

RSpec.describe Observations::PageVisitStatsService do
  include Rails.application.routes.url_helpers

  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observee_person) { create(:person) }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: company) }
  let(:observation) do
    obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_company)
    obs.observees.build(teammate: observee_teammate)
    obs.save!
    obs.publish!
    obs
  end

  describe '.call' do
    context 'when there are no page visits' do
      it 'returns zero for total_views and unique_viewers' do
        result = described_class.call(observation: observation, organization: company)

        expect(result).to eq({
          total_views: 0,
          unique_viewers: 0
        })
      end
    end

    context 'when there are page visits to the show page' do
      let(:viewer1) { create(:person) }
      let(:viewer2) { create(:person) }
      let(:show_page_url) { organization_observation_path(company, observation) }

      before do
        # Viewer 1 visits twice
        create(:page_visit, person: viewer1, url: show_page_url, visit_count: 2)
        # Viewer 2 visits once
        create(:page_visit, person: viewer2, url: show_page_url, visit_count: 1)
      end

      it 'returns correct total_views and unique_viewers' do
        result = described_class.call(observation: observation, organization: company)

        expect(result[:total_views]).to eq(3)
        expect(result[:unique_viewers]).to eq(2)
      end
    end

    context 'when there are page visits to the public permalink page' do
      let(:viewer1) { create(:person) }
      let(:viewer2) { create(:person) }
      let(:public_page_url) { observation.decorate.permalink_path }

      before do
        # Viewer 1 visits the public page twice
        create(:page_visit, person: viewer1, url: public_page_url, visit_count: 2)
        # Viewer 2 visits the public page once
        create(:page_visit, person: viewer2, url: public_page_url, visit_count: 1)
      end

      it 'returns correct total_views and unique_viewers' do
        result = described_class.call(observation: observation, organization: company)

        expect(result[:total_views]).to eq(3)
        expect(result[:unique_viewers]).to eq(2)
      end
    end

    context 'when there are page visits to both show page and public permalink' do
      let(:viewer1) { create(:person) }
      let(:viewer2) { create(:person) }
      let(:viewer3) { create(:person) }
      let(:show_page_url) { organization_observation_path(company, observation) }
      let(:public_page_url) { observation.decorate.permalink_path }

      before do
        # Viewer 1 visits show page twice
        create(:page_visit, person: viewer1, url: show_page_url, visit_count: 2)
        # Viewer 1 also visits public page once (same person, different URL)
        create(:page_visit, person: viewer1, url: public_page_url, visit_count: 1)
        # Viewer 2 visits show page once
        create(:page_visit, person: viewer2, url: show_page_url, visit_count: 1)
        # Viewer 3 visits public page twice
        create(:page_visit, person: viewer3, url: public_page_url, visit_count: 2)
      end

      it 'combines visits from both URLs' do
        result = described_class.call(observation: observation, organization: company)

        # Total views: 2 + 1 + 1 + 2 = 6
        expect(result[:total_views]).to eq(6)
        # Unique viewers: viewer1, viewer2, viewer3 = 3
        expect(result[:unique_viewers]).to eq(3)
      end
    end

    context 'when the same person visits both URLs' do
      let(:viewer) { create(:person) }
      let(:show_page_url) { organization_observation_path(company, observation) }
      let(:public_page_url) { observation.decorate.permalink_path }

      before do
        create(:page_visit, person: viewer, url: show_page_url, visit_count: 3)
        create(:page_visit, person: viewer, url: public_page_url, visit_count: 2)
      end

      it 'counts total views from both URLs but only one unique viewer' do
        result = described_class.call(observation: observation, organization: company)

        expect(result[:total_views]).to eq(5)
        expect(result[:unique_viewers]).to eq(1)
      end
    end

    context 'when there are page visits to other observations' do
      let(:other_observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_company)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
        obs
      end
      let(:viewer) { create(:person) }
      let(:show_page_url) { organization_observation_path(company, observation) }
      let(:other_show_page_url) { organization_observation_path(company, other_observation) }

      before do
        # Visit to the observation we're querying
        create(:page_visit, person: viewer, url: show_page_url, visit_count: 2)
        # Visit to a different observation (should not be counted)
        create(:page_visit, person: viewer, url: other_show_page_url, visit_count: 5)
      end

      it 'only counts visits to the specified observation' do
        result = described_class.call(observation: observation, organization: company)

        expect(result[:total_views]).to eq(2)
        expect(result[:unique_viewers]).to eq(1)
      end
    end
  end
end
