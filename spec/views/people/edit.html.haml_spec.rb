require 'rails_helper'

RSpec.describe 'people/edit', type: :view do
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }

  before do
    assign(:person, person)
    render
  end

  it 'displays the form' do
    expect(rendered).to have_selector('form[action="' + profile_path + '"][method="post"]')
  end

  it 'has first name field' do
    expect(rendered).to have_field('First Name', with: 'John')
  end

  it 'has last name field' do
    expect(rendered).to have_field('Last Name', with: 'Doe')
  end

  it 'has email field' do
    expect(rendered).to have_field('Email', with: 'john@example.com')
  end

  it 'has timezone select' do
    expect(rendered).to have_select('Timezone')
  end

  it 'has phone number field' do
    expect(rendered).to have_field('Phone Number')
  end

  it 'has middle name field' do
    expect(rendered).to have_field('Middle Name')
  end

  it 'has suffix field' do
    expect(rendered).to have_field('Suffix (Jr., Sr., etc.)')
  end

  it 'has update profile button' do
    expect(rendered).to have_button('Update Profile')
  end

  it 'has cancel link' do
    expect(rendered).to have_link('Cancel', href: profile_path)
  end

  it 'uses PATCH method' do
    expect(rendered).to have_selector('input[name="_method"][value="patch"]', visible: false)
  end
end 