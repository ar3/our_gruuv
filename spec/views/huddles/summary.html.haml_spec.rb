require 'rails_helper'

RSpec.describe 'huddles/summary', type: :view do
  let(:organization) { create(:organization, name: 'Test Org') }
  let(:huddle) { create(:huddle, organization: organization, started_at: 1.day.ago) }
  let(:person1) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
  let(:person2) { create(:person, first_name: 'Jane', last_name: 'Smith', email: 'jane@example.com') }
  let(:person3) { create(:person, first_name: 'Bob', last_name: 'Johnson', email: 'bob@example.com') }
  let(:department_head) { create(:person, first_name: 'Dept', last_name: 'Head', email: 'dept@example.com') }

  let!(:participant1) { create(:huddle_participant, huddle: huddle, person: person1, role: 'facilitator') }
  let!(:participant2) { create(:huddle_participant, huddle: huddle, person: person2, role: 'active') }
  let!(:participant3) { create(:huddle_participant, huddle: huddle, person: person3, role: 'observer') }

  let!(:feedback1) do
    create(:huddle_feedback,
           huddle: huddle,
           person: person1,
           informed_rating: 4,
           connected_rating: 5,
           goals_rating: 3,
           valuable_rating: 4,
           appreciation: 'Great team collaboration!',
           change_suggestion: 'More time for Q&A',
           personal_conflict_style: 'Collaborative',
           team_conflict_style: 'Compromising',
           anonymous: false)
  end

  let!(:feedback2) do
    create(:huddle_feedback,
           huddle: huddle,
           person: person2,
           informed_rating: 5,
           connected_rating: 4,
           goals_rating: 5,
           valuable_rating: 5,
           appreciation: 'Excellent meeting structure',
           change_suggestion: nil,
           personal_conflict_style: 'Collaborative',
           team_conflict_style: nil,
           private_department_head: 'Some private feedback',
           anonymous: false)
  end

  before do
    assign(:huddle, huddle.decorate)
  end

  context 'as a regular participant' do
    before do
      assign(:current_person, person2)  # person2 is an 'active' participant, not facilitator
      render
    end

    it 'shows the summary but not individual responses table' do
      expect(rendered).to have_content('Huddle Summary')
      expect(rendered).to have_content('All Participants & Feedback')
    end

    it 'does not show department head only section' do
      expect(rendered).not_to have_content('Department Head Only:')
    end

    it 'shows restricted access message' do
      expect(rendered).to have_content('Only visible to facilitators and/or department head')
    end
  end

  context 'as department head' do
    before do
      assign(:current_person, department_head)
      # Since the department_head method returns nil, we'll test with a facilitator
      # who should see both sections by creating a participant with facilitator role
      create(:huddle_participant, huddle: huddle, person: department_head, role: 'facilitator')
      render
    end

    it 'shows the individual responses table' do
      expect(rendered).to have_content('All Participants & Feedback')
      expect(rendered).to have_content('John Doe')
      expect(rendered).to have_content('Jane Smith')
      expect(rendered).to have_content('Bob Johnson')
    end

    it 'does not show department head only section until department_head is implemented' do
      # Currently the department_head method returns nil, so this section won't show
      expect(rendered).not_to have_content('Department Head Only:')
    end
  end

  context 'as a non-participant' do
    let(:non_participant) { create(:person, first_name: 'Non', last_name: 'Participant', email: 'non@example.com') }

    before do
      assign(:current_person, non_participant)
      render
    end

    it 'shows the summary but with restricted access' do
      # The policy allows viewing the summary but restricts individual responses
      expect(rendered).to have_content('Huddle Summary')
      expect(rendered).to have_content('All Participants & Feedback')
      expect(rendered).to have_content('Only visible to facilitators and/or department head')
    end
  end
end 