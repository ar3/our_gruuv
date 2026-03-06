# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Digest::AboutMeContentService do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
  end

  describe '#sections' do
    it 'returns an array of section hashes with section_name, status, and explanation_sentence' do
      service = described_class.new(teammate: teammate, organization: organization)
      result = service.sections

      expect(result).to be_an(Array)
      result.each do |section|
        expect(section).to have_key(:section_name)
        expect(section).to have_key(:status)
        expect(section).to have_key(:explanation_sentence)
        expect(section[:status]).to be_in([:green, :yellow, :red])
      end
    end

    it 'includes expected section names in order' do
      service = described_class.new(teammate: teammate, organization: organization)
      names = service.sections.map { |s| s[:section_name] }

      expect(names).to include('Aspirational Values Check-In', 'Position/Overall', 'Active Goals', 'Stories', '1:1 Area')
    end

    it 'returns explanation_sentence for non-green sections' do
      service = described_class.new(teammate: teammate, organization: organization)
      yellow_red = service.sections.select { |s| s[:status] == :yellow || s[:status] == :red }

      yellow_red.each do |section|
        expect(section[:explanation_sentence]).to be_present if section[:status] != :green
      end
    end
  end
end
