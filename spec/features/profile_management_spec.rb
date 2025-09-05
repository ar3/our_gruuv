require 'rails_helper'

RSpec.feature 'Profile Management', type: :feature, js: true do
  let(:company) { create(:organization, name: 'Test Company', type: 'Company') }
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com', current_organization: company) }

  before do
    page.set_rack_session(current_person_id: person.id)
  end

  scenario 'User can view their profile' do
    visit profile_path
    
    expect(page).to have_content('My Profile')
    expect(page).to have_content('John Doe')
    expect(page).to have_content('john@example.com')
    expect(page).to have_content('Gruuvin\' Since')
    expect(page).to have_content('Other Companies')
  end

  scenario 'User can edit their profile' do
    visit profile_path
    click_link 'Edit Profile'
    
    expect(page).to have_content('Edit Profile')
    expect(page).to have_field('First Name', with: 'John')
    expect(page).to have_field('Last Name', with: 'Doe')
    expect(page).to have_field('Email', with: 'john@example.com')
  end

  scenario 'User can update their profile information' do
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

  scenario 'User can cancel profile editing' do
    visit edit_profile_path
    click_link 'Cancel'
    
    expect(page).to have_current_path(profile_path)
  end

  scenario 'Profile shows timezone not set when none is configured' do
    person.update!(timezone: nil)
    visit profile_path
    
    expect(page).to have_content('Eastern Time Timezone (Default)')
  end

  scenario 'Profile shows phone number when set' do
    person.update!(unique_textable_phone_number: '+1234567890')
    visit profile_path
    
    expect(page).to have_content('+1234567890')
  end

  scenario 'Profile does not show phone section when not set' do
    person.update!(unique_textable_phone_number: nil)
    visit profile_path
    
    expect(page).to have_content('Phone: Not provided')
  end

  scenario 'User cannot access profile when not logged in' do
    page.set_rack_session(current_person_id: nil)
    
    visit profile_path
    expect(page).to have_current_path(root_path)
    expect(page).to have_css('.toast .toast-body', text: 'Please log in to access your profile', wait: 5)
  end

  scenario 'User cannot access edit profile when not logged in' do
    page.set_rack_session(current_person_id: nil)
    
    visit edit_profile_path
    expect(page).to have_current_path(root_path)
    expect(page).to have_css('.toast .toast-body', text: 'Please log in to access your profile', wait: 5)
  end
end 