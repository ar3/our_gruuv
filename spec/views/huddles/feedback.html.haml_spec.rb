require 'rails_helper'

RSpec.describe 'huddles/feedback', type: :view do
  let(:organization) { create(:organization, name: 'Test Org') }
  let(:huddle) { create(:huddle, organization: organization, started_at: 1.day.ago) }
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
  let(:facilitator) { create(:person, first_name: 'Jane', last_name: 'Smith', email: 'jane@example.com') }
  let!(:participant) { create(:huddle_participant, huddle: huddle, person: person, role: 'active') }
  let!(:facilitator_participant) { create(:huddle_participant, huddle: huddle, person: facilitator, role: 'facilitator') }
  let!(:existing_feedback) { create(:huddle_feedback, huddle: huddle, person: person) }

  before do
    assign(:huddle, huddle)
    assign(:existing_participant, participant)
    assign(:existing_feedback, existing_feedback)
    render
  end

  describe 'basic form elements' do
    it 'displays the huddle title' do
      expect(rendered).to have_content('Nat 20 Huddle Feedback')
    end

    it 'displays the huddle name' do
      expect(rendered).to have_content(huddle.display_name)
    end

    it 'shows the participant role' do
      expect(rendered).to have_content('Active Participant')
    end
  end

  describe 'rating sections' do
    it 'has informed rating field' do
      expect(rendered).to have_field('informed_rating')
    end

    it 'has connected rating field' do
      expect(rendered).to have_field('connected_rating')
    end

    it 'has goals rating field' do
      expect(rendered).to have_field('goals_rating')
    end

    it 'has valuable rating field' do
      expect(rendered).to have_field('valuable_rating')
    end
  end

  describe 'conflict styles section' do
    it 'displays conflict styles section title' do
      expect(rendered).to have_content('Conflict Styles')
    end

    it 'shows conflict styles explanation' do
      expect(rendered).to have_content('Understanding Conflict Styles')
      expect(rendered).to have_content('assertiveness')
      expect(rendered).to have_content('cooperativeness')
    end

    it 'has personal conflict style field' do
      expect(rendered).to have_field('personal_conflict_style')
    end

    it 'has team conflict style field' do
      expect(rendered).to have_field('team_conflict_style')
    end

    it 'includes all five conflict style options' do
      expect(rendered).to have_content('Collaborative')
      expect(rendered).to have_content('Competing')
      expect(rendered).to have_content('Compromising')
      expect(rendered).to have_content('Accommodating')
      expect(rendered).to have_content('Avoiding')
    end

    it 'includes conflict style descriptions' do
      expect(rendered).to have_content('High cooperativeness (speak up), High assertiveness (step up)')
      expect(rendered).to have_content('Low cooperativeness (speak up), High assertiveness (step up)')
      expect(rendered).to have_content('Medium cooperativeness (speak up), Medium assertiveness (step up)')
      expect(rendered).to have_content('High cooperativeness (speak up), Low assertiveness (step up)')
      expect(rendered).to have_content('Low cooperativeness (speak up), Low assertiveness (step up)')
    end

    it 'has proper labels for conflict style fields' do
      expect(rendered).to have_content('How did YOU think you showed up during conflicts or disagreements')
      expect(rendered).to have_content('How did you think the TEAM showed up during conflicts or disagreements')
    end
  end

  describe 'detailed feedback section' do
    it 'has appreciation field' do
      expect(rendered).to have_field('appreciation')
    end

    it 'has change suggestion field' do
      expect(rendered).to have_field('change_suggestion')
    end
  end

  describe 'private feedback section' do
    it 'has private department head field' do
      expect(rendered).to have_field('private_department_head')
    end

    it 'has private facilitator field' do
      expect(rendered).to have_field('private_facilitator')
    end

    it 'shows visibility indicators for department head' do
      expect(rendered).to have_content('No one will see this until a department head is assigned')
      expect(rendered).to have_css('.bi-eye-slash')
    end

    it 'shows visibility indicators for facilitators' do
      expect(rendered).to have_content('Only Jane Smith will see this feedback')
      expect(rendered).to have_css('.bi-eye')
    end
  end

  describe 'private feedback section without facilitators' do
    let!(:facilitator_participant) { nil } # Override to remove facilitator

    before do
      render
    end

    it 'shows no facilitator assigned message' do
      expect(rendered).to have_content('No one will see this until a facilitator is assigned')
      expect(rendered).to have_css('.bi-eye-slash')
    end
  end

  describe 'form submission' do
    it 'has submit buttons' do
      expect(rendered).to have_button('Submit Feedback Now')
      expect(rendered).to have_button('Submit Complete Feedback')
    end

    it 'has cancel link' do
      expect(rendered).to have_link('Cancel', href: huddle_path(huddle))
    end
  end

  describe 'anonymous option' do
    it 'has anonymous checkbox' do
      expect(rendered).to have_field('anonymous')
    end

    it 'explains anonymous option' do
      expect(rendered).to have_content('Submit feedback anonymously')
    end
  end
end 