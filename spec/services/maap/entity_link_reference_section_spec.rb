# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Maap::EntityLinkReferenceSection do
  include Rails.application.routes.url_helpers

  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:ability) { create(:ability, company: organization, created_by: person, updated_by: person) }

  describe '.append_to_sections!' do
    it 'adds a section whose body includes a markdown link to the ability show path' do
      sections = []
      described_class.append_to_sections!(sections, organization: organization, abilities: [ability])

      expect(sections.size).to eq(1)
      expect(sections.first['body']).to include("[#{ability.name}](#{organization_ability_path(organization, ability)})")
    end

    it 'does nothing when there are no linkable records' do
      sections = []
      described_class.append_to_sections!(sections, organization: organization)
      expect(sections).to be_empty
    end
  end
end
