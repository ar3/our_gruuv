require 'rails_helper'

RSpec.feature 'Huddle Playbooks Show Tooltip', type: :feature do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, name: 'Test Company', type: 'Company') }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:huddle_playbook) { create(:huddle_playbook, organization: organization) }
  let(:huddle) { create(:huddle, huddle_playbook: huddle_playbook) }
  let(:participant1) { create(:person, first_name: 'John', last_name: 'Doe') }
  let(:participant2) { create(:person, first_name: 'Jane', last_name: 'Smith') }
  let(:participant1_teammate) { create(:teammate, person: participant1, organization: organization) }
  let(:participant2_teammate) { create(:teammate, person: participant2, organization: organization) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
  end

  scenario 'shows participant names in tooltip' do
    # Create huddle participants
    create(:huddle_participant, huddle: huddle, teammate: participant1_teammate)
    create(:huddle_participant, huddle: huddle, teammate: participant2_teammate)

    visit organization_huddle_playbook_path(organization, huddle_playbook)

    # Check that the participant count is displayed
    expect(page).to have_content('2')

    # Check that the tooltip element exists with the correct attributes
    tooltip_element = find('span[data-bs-toggle="tooltip"]')
    
    expect(tooltip_element).to be_present
    expect(tooltip_element['title']).to include('John Doe')
    expect(tooltip_element['title']).to include('Jane Smith')
    expect(tooltip_element['data-bs-placement']).to eq('top')
  end

  scenario 'shows no tooltip when no participants' do
    visit organization_huddle_playbook_path(organization, huddle_playbook)

    # Check that the participant count is displayed as 0
    expect(page).to have_content('0')

    # Check that no tooltip element exists
    expect(page).not_to have_selector('span[data-bs-toggle="tooltip"]')
  end
end 