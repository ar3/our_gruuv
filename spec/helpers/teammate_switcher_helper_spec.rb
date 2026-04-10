# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TeammateSwitcherHelper, type: :helper do
  describe '#teammate_context_page_title' do
    it 'returns casual name, separator, and page label' do
      person = create(:person, first_name: 'Alex', last_name: 'Rivera')
      teammate = create(:company_teammate, person: person)

      expect(helper.teammate_context_page_title(teammate, 'Check-Ins')).to eq('Alex R. - Check-Ins')
    end
  end
end
