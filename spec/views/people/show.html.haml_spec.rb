require 'rails_helper'

RSpec.describe 'people/show', type: :view do
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com', timezone: 'Eastern Time (US & Canada)') }
  let(:organization) { create(:organization, type: 'Company') }

  before do
    assign(:person, person)
    assign(:employment_tenures, [])
    assign(:assignment_tenures, [])
    assign(:current_person, person)
    
    # Manually define the current_organization and current_person methods on the view
    org = organization # Capture the variable
    current_person_obj = person # Capture the variable
    view.define_singleton_method(:current_organization) { org }
    view.define_singleton_method(:current_person) { current_person_obj }
    
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
    expect(rendered).to have_content('Gruuvin\' Since')
    expect(rendered).to have_content('Other Companies')
  end

  context 'when person has no timezone' do
    let(:person) { create(:person, timezone: nil) }

      it 'shows timezone not set message' do
    expect(rendered).to have_content('Eastern Time')
    expect(rendered).to have_content('Timezone (Default)')
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
      expect(rendered).to have_content('Not provided')
    end
  end
end 