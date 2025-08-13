require 'rails_helper'

RSpec.describe 'huddles/_huddle_card for non-participants', type: :view do
  let(:organization) { create(:organization, name: 'Test Org') }
  let(:huddle) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization), started_at: 1.day.ago) }
  let(:non_participant) { create(:person, first_name: 'Jane', last_name: 'Smith', email: 'jane@example.com') }

  before do
    render partial: 'huddles/huddle_card', locals: { huddle: huddle, current_person: non_participant }
  end

  it 'displays the huddle name without organization' do
    expect(rendered).to have_content(huddle.display_name_without_organization)
  end

  it 'shows team label' do
    expect(rendered).to have_content('Team:')
  end

  it 'has join huddle link' do
    expect(rendered).to have_link('Join Huddle', href: join_huddle_path(huddle))
  end

  it 'does not have view huddle or summary links' do
    expect(rendered).not_to have_link('View Huddle')
    expect(rendered).not_to have_link('Summary')
  end
end 