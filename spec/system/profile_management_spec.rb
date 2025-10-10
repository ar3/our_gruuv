require 'rails_helper'

RSpec.describe 'Profile Management', type: :system, critical: true, js: true do
  let(:company) { create(:organization, name: 'Test Company', type: 'Company') }
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com', current_organization: company) }

  before do
    page.set_rack_session(current_person_id: person.id)
  end

  it 'User can view their profile' do
    visit profile_path
    
    expect(page).to have_content('My Profile')
    expect(page).to have_content('John Doe')
    expect(page).to have_content('john@example.com')
    expect(page).to have_content('Gruuvin\' Since')
    expect(page).to have_content('Other Companies')
  end


  it 'User can update their profile information' do
    visit edit_profile_path
    
    fill_in 'First Name', with: 'Jane'
    fill_in 'Last Name', with: 'Smith'
    fill_in 'Middle Name', with: 'Marie'
    fill_in 'Suffix (Jr., Sr., etc.)', with: 'Jr.'
    fill_in 'Phone Number', with: '+1234567890'
    select 'Pacific Time (US & Canada)', from: 'Timezone'
    
    click_button 'Update Profile'
    
    expect(page).to have_current_path(profile_path)
    expect(page).to have_content('Profile updated successfully!')
    expect(page).to have_content('Jane Marie Smith Jr.')
    expect(page).to have_content('+1234567890')
    expect(page).to have_content('Pacific Time (US & Canada)')
  end


  it 'Profile shows timezone not set when none is configured' do
    person.update!(timezone: nil)
    visit profile_path
    
    expect(page).to have_content('Eastern Time Timezone (Default)')
  end

  it 'Profile shows phone number when set' do
    person.update!(unique_textable_phone_number: '+1234567890')
    visit profile_path
    
    expect(page).to have_content('+1234567890')
  end



end 