require 'rails_helper'

RSpec.feature 'Feedback Update', type: :feature do
  let(:person) { create(:person, full_name: 'Test User', email: 'test@example.com') }
  let(:organization) { create(:organization, name: 'Test Company', type: 'Company') }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:huddle) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization), started_at: 1.hour.ago) }
  let(:participant) { create(:huddle_participant, huddle: huddle, teammate: teammate, role: 'facilitator') }
  let(:existing_feedback) do
    create(:huddle_feedback,
           huddle: huddle,
           teammate: teammate,
           informed_rating: 4,
           connected_rating: 3,
           goals_rating: 5,
           valuable_rating: 4,
           personal_conflict_style: 'Collaborative',
           team_conflict_style: 'Compromising',
           appreciation: 'Great teamwork and communication',
           change_suggestion: 'Could use more time for discussion',
           private_department_head: 'Private note for department head',
           private_facilitator: 'Private note for facilitator',
           anonymous: false)
  end

  before do
    participant # Create the participant
    existing_feedback # Create the existing feedback
    page.set_rack_session(current_person_id: person.id)
  end

  scenario 'update feedback form pre-populates all previous answers' do
    visit feedback_huddle_path(huddle)

    # Check that all rating sliders are pre-populated
    expect(page).to have_field('informed_rating', with: '4')
    expect(page).to have_field('connected_rating', with: '3')
    expect(page).to have_field('goals_rating', with: '5')
    expect(page).to have_field('valuable_rating', with: '4')

    # Check that conflict style dropdowns are pre-populated
    expect(page).to have_select('personal_conflict_style', selected: 'Collaborative - High cooperativeness (speak up), High assertiveness (step up) - Seeks win-win solutions')
    expect(page).to have_select('team_conflict_style', selected: 'Compromising - Medium cooperativeness (speak up), Medium assertiveness (step up) - Seeks middle ground')

    # Check that text areas are pre-populated
    expect(page).to have_field('appreciation', with: 'Great teamwork and communication')
    expect(page).to have_field('change_suggestion', with: 'Could use more time for discussion')
    expect(page).to have_field('private_department_head', with: 'Private note for department head')
    expect(page).to have_field('private_facilitator', with: 'Private note for facilitator')

    # Check that anonymous checkbox is pre-populated
    expect(page).to have_unchecked_field('anonymous')

    # Check that submit button shows "Update" text
    expect(page).to have_button('Update Complete Feedback')
  end

  scenario 'update feedback form allows editing and saving changes' do
    visit feedback_huddle_path(huddle)

    # Modify some values
    fill_in 'appreciation', with: 'Updated appreciation text'
    fill_in 'change_suggestion', with: 'Updated suggestion text'
    select 'Accommodating - High cooperativeness (speak up), Low assertiveness (step up) - Yields to others\' concerns', from: 'personal_conflict_style'
    select 'Avoiding - Low cooperativeness (speak up), Low assertiveness (step up) - Withdraws from conflict', from: 'team_conflict_style'

    # Submit the form
    click_button 'Update Complete Feedback'

    # Should redirect to huddle page with success message
    expect(page).to have_current_path(huddle_path(huddle))
    expect(page).to have_content('Your feedback has been updated!')

    # Verify the changes were saved
    existing_feedback.reload
    expect(existing_feedback.appreciation).to eq('Updated appreciation text')
    expect(existing_feedback.change_suggestion).to eq('Updated suggestion text')
    expect(existing_feedback.personal_conflict_style).to eq('Accommodating')
    expect(existing_feedback.team_conflict_style).to eq('Avoiding')
  end

  scenario 'update feedback form shows correct button text' do
    visit feedback_huddle_path(huddle)

    # Should show "Update" text in both submit buttons
    expect(page).to have_button('Update Feedback Now')
    expect(page).to have_button('Update Complete Feedback')
  end
end 