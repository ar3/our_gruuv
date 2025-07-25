require 'rails_helper'

RSpec.describe 'people/show', type: :view do
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com', timezone: 'Eastern Time (US & Canada)') }

  before do
    assign(:person, person)
    render
  end

  it 'displays the person name' do
    expect(rendered).to have_content('John Doe')
  end

  it 'displays the person email' do
    expect(rendered).to have_content('john@example.com')
  end

  it 'displays the timezone' do
    expect(rendered).to have_content('Eastern Time (US & Canada)')
  end

  it 'has an edit profile link' do
    expect(rendered).to have_link('Edit Profile', href: edit_profile_path)
  end

  it 'displays account statistics' do
    expect(rendered).to have_content('Account Statistics')
    expect(rendered).to have_content('Huddles Participated')
    expect(rendered).to have_content('Feedback Submitted')
    expect(rendered).to have_content('Member Since')
  end

  context 'when person has no timezone' do
    let(:person) { create(:person, timezone: nil) }

      it 'shows timezone not set message' do
    expect(rendered).to have_content('Not set (using Eastern Time)')
  end
  end

  context 'when person has phone number' do
    let(:person) { create(:person, unique_textable_phone_number: '+1234567890') }

    it 'displays the phone number' do
      expect(rendered).to have_content('+1234567890')
    end
  end

  context 'when person has no phone number' do
    let(:person) { create(:person, unique_textable_phone_number: nil) }

    it 'does not display phone section' do
      expect(rendered).not_to have_content('Phone:')
    end
  end
end 