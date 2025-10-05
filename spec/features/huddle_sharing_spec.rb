require 'rails_helper'

RSpec.feature 'Huddle Sharing', type: :feature, js: true do
  let(:organization) { create(:organization, name: 'Test Org') }
  let(:huddle) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization), started_at: Time.current) }
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let!(:participant) { create(:huddle_participant, huddle: huddle, teammate: teammate, role: 'active') }

  before do
    # Set up session
    page.set_rack_session(current_person_id: person.id)
  end




  scenario 'Share button shows link icon' do
    visit huddles_path
    
    share_button = find('.share-huddle-btn')
    expect(share_button).to have_css('.bi-link-45deg')
  end

end 