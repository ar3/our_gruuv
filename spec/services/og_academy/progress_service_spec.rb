# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OgAcademy::ProgressService do
  let(:company) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: company) }

  subject(:service) { described_class.new(organization: company, company_teammate: teammate) }

  describe '#levels' do
    it 'returns five levels without creating real milestones' do
      expect {
        levels = service.levels
        expect(levels.map(&:level)).to eq([1, 2, 3, 4, 5])
        expect(levels.first.criteria.map(&:key)).to include(:logged_in, :zero_actions, :published_ogo)
        expect(levels.last.placeholder).to eq(true)
      }.not_to change(TeammateMilestone, :count)
    end

    it 'marks logged_in complete when viewing' do
      logged_in = service.levels[0].criteria.find { |c| c.key == :logged_in }
      expect(logged_in.done).to eq(true)
    end

    it 'marks published_ogo when the person has a published observation in company' do
      build(:observation,
            observer: person,
            company: company,
            privacy_level: :public_to_company,
            observed_at: 1.day.ago,
            published_at: 1.day.ago).tap do |obs|
        obs.observees.build(teammate: teammate)
        obs.save!
      end

      criterion = service.levels[0].criteria.find { |c| c.key == :published_ogo }
      expect(criterion.done).to eq(true)
    end

    it 'collapses advanced track for non-managers without admin flags' do
      expect(service.collapsed_advanced?).to eq(true)
      expect(service.has_direct_reports?).to eq(false)
    end
  end
end
