# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::SearchHelper, type: :helper do
  let(:organization) { create(:organization) }
  let(:department) { create(:department, company: organization, name: 'Engineering') }

  before do
    helper.instance_variable_set(:@organization, organization)
  end

  describe '#search_department_cell' do
    it 'links to the department when present' do
      ability = build(:ability, company: organization, department: department)
      html = helper.search_department_cell(ability)

      expect(html).to include('Engineering')
      expect(html).to include(organization_department_path(organization, department))
    end

    it 'shows muted text when department is absent' do
      ability = build(:ability, company: organization, department: nil)
      html = helper.search_department_cell(ability)

      expect(html).to include('No department')
      expect(html).to include('text-muted')
    end
  end
end
