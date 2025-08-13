require 'rails_helper'

RSpec.describe 'huddles/_huddle_card', type: :view do
  let(:organization) { create(:organization, name: 'Test Org') }
  let(:huddle) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization), started_at: 1.day.ago) }
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
  let!(:participant) { create(:huddle_participant, huddle: huddle, person: person, role: 'active') }

  before do
    assign(:current_person, person)
  end

  context 'when participant has not submitted feedback' do
    before do
      render partial: 'huddles/huddle_card', locals: { huddle: huddle, current_person: person }
    end

    it 'displays the huddle name' do
      expect(rendered).to have_content(huddle.display_name_without_organization)
    end

    it 'displays the organization name' do
      expect(rendered).to have_content(organization.display_name)
    end

    it 'shows team label for participants' do
      expect(rendered).to have_content('Team:')
    end

    it 'has view huddle link for participants' do
      expect(rendered).to have_link('View Huddle', href: huddle_path(huddle))
    end

    it 'shows submit feedback button when participant has not submitted feedback' do
      expect(rendered).to have_link('Submit Feedback', href: feedback_huddle_path(huddle))
    end

    it 'displays the start time in tooltip' do
      expect(rendered).to have_css("h5[title*='Started at']")
    end

    it 'displays the participant role' do
      expect(rendered).to have_content('Active')
    end

    it 'has a share button' do
      expect(rendered).to have_css('.share-huddle-btn')
    end

    it 'share button has correct attributes' do
      expect(rendered).to have_css('.share-huddle-btn[data-huddle-id]')
      expect(rendered).to have_css('.share-huddle-btn[data-join-url]')
      expect(rendered).to have_css('.share-huddle-btn[title="Share this huddle"]')
    end

    it 'share button has link icon' do
      expect(rendered).to have_css('.share-huddle-btn .bi-link-45deg')
    end

    it 'share button is positioned in top-right corner' do
      expect(rendered).to have_css('.card-body.position-relative')
      expect(rendered).to have_css('.position-absolute.top-0.end-0')
    end
  end

  context 'when participant has submitted feedback' do
    let!(:feedback) { create(:huddle_feedback, huddle: huddle, person: person) }
    
    before do
      render partial: 'huddles/huddle_card', locals: { huddle: huddle, current_person: person }
    end

    it 'does not show submit feedback button' do
      expect(rendered).not_to have_link('Submit Feedback')
    end

    it 'shows view huddle button' do
      expect(rendered).to have_link('View Huddle', href: huddle_path(huddle))
    end

    context 'when slack announcement exists' do
      let!(:slack_config) { create(:slack_configuration, organization: organization, workspace_url: 'https://test-workspace.slack.com') }
      let!(:notification) do
        huddle.notifications.create!(
          notification_type: 'huddle_announcement',
          status: 'sent_successfully',
          message_id: '1234567890.123456',
          metadata: { channel: 'general' }
        )
      end
      
      before do
        render partial: 'huddles/huddle_card', locals: { huddle: huddle, current_person: person }
      end

      it 'shows slack thread button' do
        expect(rendered).to have_link('Slack')
        expect(rendered).to have_css('a[target="_blank"]')
        expect(rendered).to have_css('a[title="View Slack Thread"]')
      end
    end
  end

  it 'displays nat 20 score if available' do
    create(:huddle_feedback, huddle: huddle, person: person, informed_rating: 4, connected_rating: 5, goals_rating: 4, valuable_rating: 5)
    render partial: 'huddles/huddle_card', locals: { huddle: huddle, current_person: person }
    expect(rendered).to have_content('18.0')
  end

  it 'displays feedback count' do
    create(:huddle_feedback, huddle: huddle, person: person)
    render partial: 'huddles/huddle_card', locals: { huddle: huddle, current_person: person }
    expect(rendered).to have_content('1 of 1')
  end
end 