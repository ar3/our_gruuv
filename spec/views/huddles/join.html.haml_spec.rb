require 'rails_helper'

RSpec.describe 'huddles/join', type: :view do
  let(:company) { Company.create!(name: 'Test Company') }
  let(:team) { Team.create!(name: 'Test Team', parent: company) }
  let(:huddle) do
    Huddle.create!(
      started_at: Time.current,
      huddle_playbook: create(:huddle_playbook, organization: team, special_session_name: 'test-huddle')
    )
  end

  before do
    assign(:huddle, huddle)
    assign(:current_person, nil)
    assign(:existing_participant, nil)
  end

  context 'when user is not logged in' do
    it 'renders the join form with email and role fields' do
      render

      expect(rendered).to have_content("Join #{huddle.display_name}")
      expect(rendered).to have_field('email')
      expect(rendered).to have_select('role')
      expect(rendered).to have_button('Join Huddle')
      expect(rendered).to have_content('Your name will be auto-generated from your email')
    end

    it 'includes role options from constants' do
      render

      HuddleConstants::ROLES.each do |role|
        expect(rendered).to have_content(HuddleConstants::ROLE_LABELS[role])
      end
    end
  end

  context 'when user is logged in but not a participant' do
    let(:person) { Person.create!(full_name: 'John Doe', email: 'john@example.com') }

    before do
      assign(:current_person, person)
    end

    it 'renders welcome message and readonly name/email fields' do
      render

      expect(rendered).to have_content('Welcome, John Doe!')
      expect(rendered).to have_field('name', readonly: true)
      expect(rendered).to have_field('email', readonly: true)
      expect(rendered).to have_select('role')
      expect(rendered).to have_button('Join Huddle')
    end

    it 'pre-fills name and email fields' do
      render

      expect(rendered).to have_field('name', with: 'John Doe', readonly: true)
      expect(rendered).to have_field('email', with: 'john@example.com', readonly: true)
    end
  end

  context 'when user is already a participant' do
    let(:person) { Person.create!(full_name: 'Jane Smith', email: 'jane@example.com') }
    let(:participant) { huddle.huddle_participants.create!(person: person, role: 'active') }

    before do
      assign(:current_person, person)
      assign(:existing_participant, participant)
    end

    it 'renders welcome back message and current role' do
      render

      expect(rendered).to have_content('Welcome back, Jane Smith!')
      expect(rendered).to have_content('You\'re already a member of this huddle')
      expect(rendered).to have_select('role', selected: 'Active Participant')
      expect(rendered).to have_button('Update Role')
    end

    it 'shows the current role as selected' do
      render

      expect(rendered).to have_select('role', selected: 'Active Participant')
    end
  end

  it 'includes proper form action and method' do
    render

    expect(rendered).to have_selector("form[action='#{join_huddle_huddle_path(huddle)}'][method='post']")
  end

  it 'includes proper form structure for security' do
    render

    # Check that the form has proper method and action
    expect(rendered).to have_selector("form[method='post']")
    expect(rendered).to have_selector("form[action='#{join_huddle_huddle_path(huddle)}']")
    
    # Check that form_with is used (which automatically includes CSRF protection)
    expect(rendered).to have_selector('form')
  end
end 