require 'rails_helper'

RSpec.feature 'Huddles', type: :feature do
  let(:company) { Company.create!(name: 'Test Company') }
  let(:team) { Team.create!(name: 'Test Team', parent: company) }
  let(:huddle) do
    playbook = create(:huddle_playbook, organization: team, special_session_name: 'test-huddle')
    Huddle.create!(
      organization: team,
      started_at: Time.current,
      huddle_playbook: playbook
    )
  end

  before do
    # Clear any existing test data
    Huddle.destroy_all
    Person.destroy_all
    Company.destroy_all
  end

  scenario 'visiting the huddles index' do
    visit huddles_path
    
    expect(page).to have_content('S.E.E. 20 Huddles')
    expect(page).to have_content("Today's Huddles")
    expect(page).to have_link('Start New Huddle')
  end

  scenario 'index shows only active huddles' do
    # Create a huddle for today
    today_playbook = create(:huddle_playbook, organization: team, special_session_name: 'today-huddle')
    today_huddle = Huddle.create!(
      organization: team,
      started_at: Time.current,
      huddle_playbook: today_playbook
    )
    
    # Create a huddle that's expired (25 hours ago, expires 1 hour ago)
    expired_playbook = create(:huddle_playbook, organization: team, special_session_name: 'expired-huddle')
    expired_huddle = Huddle.create!(
      organization: team,
      started_at: 25.hours.ago,
      expires_at: 1.hour.ago,
      huddle_playbook: expired_playbook
    )
    
    visit huddles_path
    
    # Should show today's huddle
    expect(page).to have_content('today-huddle')
    
    # Should not show expired huddle
    expect(page).not_to have_content('expired-huddle')
  end

  scenario 'viewing my huddles when logged in' do
    person = Person.create!(full_name: 'Alice Johnson', email: 'alice@example.com')
    
    # Create huddles where person participated
    playbook1 = create(:huddle_playbook, organization: team, special_session_name: 'yesterday-huddle')
    huddle1 = Huddle.create!(organization: team, started_at: 1.day.ago, huddle_playbook: playbook1)
    huddle1.huddle_participants.create!(person: person, role: 'facilitator')
    
    playbook2 = create(:huddle_playbook, organization: team, special_session_name: 'older-huddle')
    huddle2 = Huddle.create!(organization: team, started_at: 2.days.ago, huddle_playbook: playbook2)
    huddle2.huddle_participants.create!(person: person, role: 'active')
    
    # Simulate being logged in
    page.set_rack_session(current_person_id: person.id)
    
    visit my_huddles_path
    
    expect(page).to have_content('My Huddles')
    expect(page).to have_content('yesterday-huddle')
    expect(page).to have_content('older-huddle')
    expect(page).to have_content('Facilitator')
    expect(page).to have_content('Active')
  end

  scenario 'viewing my huddles when not logged in redirects to huddles' do
    visit my_huddles_path
    
    expect(page).to have_content('Please log in to view your huddles')
    expect(current_path).to eq(huddles_path)
  end

  scenario 'viewing huddle summary as participant' do
    person = Person.create!(full_name: 'Bob Wilson', email: 'bob@example.com')
    huddle.huddle_participants.create!(person: person, role: 'facilitator')
    
    # Add some feedback
    huddle.huddle_feedbacks.create!(
      person: person,
      informed_rating: 4,
      connected_rating: 5,
      goals_rating: 4,
      valuable_rating: 5,
      appreciation: 'Great collaboration!',
      change_suggestion: 'More time for Q&A'
    )
    
    # Simulate being logged in
    page.set_rack_session(current_person_id: person.id)
    
    visit huddle_path(huddle)
    
    expect(page).to have_content('Evolve')
    expect(page).to have_content('Test Company > Test Team')
    expect(page).to have_content('4.0') # Average rating
    expect(page).to have_content('Great collaboration!')
    expect(page).to have_content('More time for Q&A')
    expect(page).to have_content('1 of 1 participants submitted feedback')
  end

  scenario 'viewing huddle summary when not logged in redirects to join' do
    visit huddle_path(huddle)
    
    expect(page).to have_content('Join Huddle')
    expect(page).to have_content('Please provide your email to join this huddle')
    expect(current_path).to eq(join_huddle_path(huddle))
  end

  scenario 'viewing huddle summary when not a participant redirects to join' do
    person = Person.create!(full_name: 'Charlie Brown', email: 'charlie@example.com')
    
    # Simulate being logged in but not a participant
    page.set_rack_session(current_person_id: person.id)
    
    visit huddle_path(huddle)
    
    expect(page).to have_content('Join Huddle')
    expect(page).to have_content('Welcome, Charlie Brown!')
    expect(current_path).to eq(join_huddle_path(huddle))
  end

  scenario 'huddle summary shows insights and participation data' do
    person1 = Person.create!(full_name: 'Alice Johnson', email: 'alice@example.com')
    person2 = Person.create!(full_name: 'Bob Wilson', email: 'bob@example.com')
    
    huddle.huddle_participants.create!(person: person1, role: 'facilitator')
    huddle.huddle_participants.create!(person: person2, role: 'active')
    
    # Only one person submits feedback
    huddle.huddle_feedbacks.create!(
      person: person1,
      informed_rating: 3,
      connected_rating: 4,
      goals_rating: 3,
      valuable_rating: 4,
      appreciation: 'Good discussion',
      change_suggestion: 'Need more time'
    )
    
    # Simulate being logged in
    page.set_rack_session(current_person_id: person1.id)
    
    visit huddle_path(huddle)
    
    expect(page).to have_content('1 of 2 participants submitted feedback')
    expect(page).to have_content('Good discussion')
    expect(page).to have_content('Need more time')
  end

  scenario 'creating a new huddle when not logged in' do
    visit new_huddle_path
    
    select '+ Create new company', from: 'Company'
    fill_in 'New company name', with: 'New Company'
    fill_in 'New team name', with: 'New Team'
    fill_in 'Your email', with: 'john@example.com'
    
    click_button 'Start Huddle'
    
    expect(page).to have_content('Huddle created successfully!')
    expect(page).to have_content('New Company > New Team')
    expect(page).to have_content('John') # Auto-generated from email
  end

  scenario 'creating a new huddle when already logged in' do
    person = Person.create!(full_name: 'Jane Smith', email: 'jane@example.com')
    
    # Simulate being logged in by setting session
    page.set_rack_session(current_person_id: person.id)
    
    visit new_huddle_path
    
    # Should show logged in state with readonly email field
    expect(page).to have_content('Welcome, Jane Smith!')
    expect(page).to have_field('email', readonly: true, with: 'jane@example.com')
    
    select '+ Create new company', from: 'Company'
    fill_in 'New company name', with: 'New Company'
    fill_in 'New team name', with: 'New Team'
    
    click_button 'Start Huddle'
    
    expect(page).to have_content('Huddle created successfully!')
    expect(page).to have_content('New Company > New Team')
    expect(page).to have_content('Jane Smith')
  end

  scenario 'joining an existing huddle when not logged in' do
    visit join_huddle_path(huddle)
    
    # Should show the join form asking for email and role (name auto-generated)
    expect(page).to have_content("Join #{huddle.display_name}")
    expect(page).to have_field('email')
    expect(page).to have_select('role')
    expect(page).to have_content('Your name will be auto-generated from your email')
    
    fill_in 'Your email', with: 'jane@example.com'
    select 'Active Participant', from: 'What role will you play in this huddle?'
    
    click_button 'Join Huddle'
    
    expect(page).to have_content('Welcome to the huddle!')
    expect(page).to have_content('Jane') # Auto-generated name from email
  end

  scenario 'joining an existing huddle when already logged in' do
    person = Person.create!(full_name: 'Bob Wilson', email: 'bob@example.com')
    
    # Simulate being logged in by setting session
    page.set_rack_session(current_person_id: person.id)
    
    visit join_huddle_path(huddle)
    
    # Should show logged in state with readonly name/email fields
    expect(page).to have_content('Welcome, Bob Wilson!')
    expect(page).to have_field('name', readonly: true)
    expect(page).to have_field('email', readonly: true)
    expect(page).to have_select('role')
    
    select 'Observer', from: 'What role will you play in this huddle?'
    click_button 'Join Huddle'
    
    expect(page).to have_content('Welcome to the huddle!')
  end

  scenario 'updating role when already a participant' do
    person = Person.create!(full_name: 'Alice Johnson', email: 'alice@example.com')
    huddle.huddle_participants.create!(person: person, role: 'active')
    
    # Simulate being logged in
    page.set_rack_session(current_person_id: person.id)
    
    visit join_huddle_path(huddle)
    
    # Should show "Welcome back" message and current role
    expect(page).to have_content('Welcome back, Alice Johnson!')
    expect(page).to have_content('You\'re already a member of this huddle')
    
    select 'Facilitator', from: 'Your Role in This Huddle'
    click_button 'Update Role'
    
    expect(page).to have_content('Role updated successfully!')
    expect(huddle.huddle_participants.find_by(person: person).role).to eq('facilitator')
  end

  scenario 'submitting feedback when not logged in' do
    visit feedback_huddle_path(huddle)
    
    # Should redirect to join page
    expect(page).to have_content("Join #{huddle.display_name}")
    expect(page).to have_content('Please join the huddle before accessing this page')
  end

  scenario 'submitting feedback when logged in' do
    person = Person.create!(full_name: 'Charlie Brown', email: 'charlie@example.com')
    huddle.huddle_participants.create!(person: person, role: 'active')
    
    # Simulate being logged in
    page.set_rack_session(current_person_id: person.id)
    
    visit feedback_huddle_path(huddle)
    
    # Should show feedback form
    expect(page).to have_content('Nat 20 Huddle Feedback')
    expect(page).to have_content("Share your thoughts on #{huddle.display_name}")
    expect(page).to have_content('Your Role: Active Participant')
    
    # Fill out the feedback form with range sliders (0-5 scale)
    find('input[name="informed_rating"]').set(4)
    find('input[name="connected_rating"]').set(5)
    find('input[name="goals_rating"]').set(4)
    find('input[name="valuable_rating"]').set(5)
    
    fill_in 'What went well in this huddle?', with: 'Great discussion and collaboration'
    fill_in 'What could be improved?', with: 'Could use more time for Q&A'
    
    click_button 'Submit Feedback'
    
    expect(page).to have_content('Thank you for your feedback!')
    expect(huddle.huddle_feedbacks.count).to eq(1)
  end

  scenario 'logout functionality' do
    person = Person.create!(full_name: 'David Lee', email: 'david@example.com')
    
    # Simulate being logged in
    page.set_rack_session(current_person_id: person.id)
    
    visit huddles_path
    
    # Should show user dropdown in navbar
    expect(page).to have_selector('.navbar', text: 'David Lee')
    
    # Click logout - find the user dropdown specifically
    find('.navbar-nav:last-child .dropdown-toggle').click
    click_button 'Logout'
    
    expect(page).to have_content('You have been logged out successfully')
    expect(page).not_to have_selector('.navbar', text: 'David Lee')
  end

  scenario 'huddle display shows correct information' do
    person = Person.create!(full_name: 'Eve Wilson', email: 'eve@example.com')
    huddle.huddle_participants.create!(person: person, role: 'facilitator')
    
    # Set up session for the person
    page.set_rack_session(current_person_id: person.id)
    
    visit huddle_path(huddle)
    
    expect(page).to have_content(huddle.display_name)
    expect(page).to have_content('Test Company > Test Team')
    expect(page).to have_content('Participants: 0 of 1 participants submitted feedback')
    expect(page).to have_link('Submit Your Feedback')
  end

  scenario 'allows multiple huddles for same organization' do
    # Create a huddle for today
    existing_huddle = Huddle.create!(
      organization: team,
      started_at: Time.current
    )
    
    visit new_huddle_path
    
    select '+ Create new company', from: 'Company'
    fill_in 'New company name', with: 'Test Company'
    fill_in 'New team name', with: 'Test Team'
    fill_in 'Your email', with: 'frank@example.com'
    
    click_button 'Start Huddle'
    
    # Should create a new huddle
    expect(page).to have_content('Huddle created successfully!')
    expect(current_path).not_to eq(huddle_path(existing_huddle))
  end



  scenario 'updates existing person name when joining with different name' do
    # Create a person with initial name
    existing_person = Person.create!(
      email: 'john.doe@example.com',
      full_name: 'John Smith'
    )
    
    visit join_huddle_path(huddle)
    
    # Join with email (name should NOT be auto-generated since person already has a name)
    fill_in 'Your email', with: 'john.doe@example.com'
    select 'Active Participant', from: 'What role will you play in this huddle?'
    
    click_button 'Join Huddle'
    
    expect(page).to have_content('Welcome to the huddle!')
    expect(page).to have_content('John Smith') # Original name should be preserved
    
    # Verify the person's name was NOT updated in the database
    existing_person.reload
    expect(existing_person.full_name).to eq('John Smith') # Should remain unchanged
    expect(existing_person.first_name).to eq('John')
    expect(existing_person.last_name).to eq('Smith')
  end

  scenario 'preserves existing person name when creating huddle' do
    # Create a person with initial name
    existing_person = Person.create!(
      email: 'jane@example.com',
      full_name: 'Jane Smith'
    )
    
    visit new_huddle_path
    
    # Create huddle (name will be auto-generated from email)
    select '+ Create new company', from: 'Company'
    fill_in 'New company name', with: 'New Company'
    fill_in 'New team name', with: 'New Team'
    fill_in 'Your email', with: 'jane@example.com'
    
    click_button 'Start Huddle'
    
    expect(page).to have_content('Huddle created successfully!')
    expect(page).to have_content('Jane') # Auto-generated from email
    
    # Verify the person's name was NOT updated in the database (no name field in form)
    existing_person.reload
    expect(existing_person.full_name).to eq('Jane Smith') # Should remain unchanged
    expect(existing_person.first_name).to eq('Jane')
    expect(existing_person.last_name).to eq('Smith')
  end
end 