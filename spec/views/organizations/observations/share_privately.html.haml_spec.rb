require 'rails_helper'

RSpec.describe 'organizations/observations/share_privately', type: :view do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee_person) { create(:person, first_name: 'John', last_name: 'Doe') }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: company) }
  let(:observation) do
    obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_company)
    obs.observees.build(teammate: observee_teammate)
    obs.save!
    obs.publish!
    obs
  end

  before do
    observer_teammate # Ensure observer teammate is created
    assign(:organization, company)
    assign(:observation, observation)
    assign(:return_url, organization_observation_path(company, observation))
    assign(:return_text, 'Back to Observation')
    
    # Mock policy
    allow(view).to receive(:policy).and_return(double(post_to_slack?: true))
    
    # Mock route helpers
    allow(view).to receive(:post_to_slack_organization_observation_path).and_return("/organizations/#{company.id}/observations/#{observation.id}/post_to_slack")
  end

  context 'when teammates are available' do
    before do
      assign(:available_teammates, [{
        teammate: observee_teammate,
        role: 'Observed',
        person: observee_person,
        disabled: false,
        disabled_reason: nil
      }])
      render
    end

    it 'displays the card header' do
      expect(rendered).to include('Select Teammates to Notify')
    end

    it 'displays teammates as checkboxes' do
      expect(rendered).to have_css('input[type="checkbox"][name="notify_teammate_ids[]"]')
      expect(rendered).to include('John')
      expect(rendered).to include('Observed')
    end

    it 'displays Send Now and Cancel buttons' do
      expect(rendered).to have_button('Send Now')
      expect(rendered).to have_link('Cancel')
    end

    it 'has form that submits to post_to_slack' do
      expect(rendered).to have_css("form[action*='post_to_slack']")
    end
  end

  context 'when teammate is disabled due to no Slack identity' do
    before do
      assign(:available_teammates, [{
        teammate: observee_teammate,
        role: 'Observed',
        person: observee_person,
        disabled: true,
        disabled_reason: 'Slack not configured for them'
      }])
      render
    end

    it 'disables the checkbox' do
      expect(rendered).to have_css('input[type="checkbox"][disabled]')
    end

    it 'displays warning icon with tooltip' do
      expect(rendered).to have_css('i.bi.bi-exclamation-triangle')
      expect(rendered).to have_css('[data-bs-toggle="tooltip"]')
      expect(rendered).to have_css('[data-bs-title="Slack not configured for them"]')
    end
  end

  context 'when teammate is disabled due to already notified' do
    before do
      assign(:available_teammates, [{
        teammate: observee_teammate,
        role: 'Observed',
        person: observee_person,
        disabled: true,
        disabled_reason: 'Already notified in a prior notification'
      }])
      render
    end

    it 'disables the checkbox' do
      expect(rendered).to have_css('input[type="checkbox"][disabled]')
    end

    it 'displays warning icon with tooltip' do
      expect(rendered).to have_css('i.bi.bi-exclamation-triangle')
      expect(rendered).to have_css('[data-bs-toggle="tooltip"]')
      expect(rendered).to have_css('[data-bs-title="Already notified in a prior notification"]')
    end
  end

  context 'when no teammates are available' do
    before do
      assign(:available_teammates, [])
      render
    end

    it 'displays info message' do
      expect(rendered).to include('No teammates available for notification')
    end

    it 'disables Send Now button' do
      expect(rendered).to have_css('input[type="submit"][disabled][value="Send Now"]')
    end
  end

  it 'includes JavaScript for Bootstrap tooltips' do
    assign(:available_teammates, [{
      teammate: observee_teammate,
      role: 'Observed',
      person: observee_person,
      disabled: true,
      disabled_reason: 'Slack not configured for them'
    }])
    render
    expect(rendered).to include('bootstrap.Tooltip')
  end
end

