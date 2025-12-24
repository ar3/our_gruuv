require 'rails_helper'

RSpec.describe 'organizations/observations/share_publicly', type: :view do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee_person) { create(:person) }
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
    allow(view).to receive(:channels_organization_slack_path).and_return("/organizations/#{company.id}/slack/channels")
  end

  context 'when kudos channels are available' do
    let(:kudos_channel) { create(:third_party_object, :slack_channel, organization: company, third_party_id: 'C123456', display_name: 'kudos') }
    
    before do
      company.kudos_channel_id = kudos_channel.third_party_id
      company.save!
      assign(:kudos_channel_organizations, [{
        organization: company,
        channel: kudos_channel,
        display_name: "#{company.display_name} - #{kudos_channel.display_name}",
        already_sent: false
      }])
      render
    end

    it 'displays the card header' do
      expect(rendered).to include('Select Kudos Channel')
    end

    it 'displays kudos channel options as radio buttons' do
      expect(rendered).to have_css('input[type="radio"][name="kudos_channel_organization_id"]')
      expect(rendered).to include("#{company.display_name} - #{kudos_channel.display_name}")
    end

    it 'displays Send Now and Cancel buttons' do
      expect(rendered).to have_button('Send Now')
      expect(rendered).to have_link('Cancel')
    end

    it 'has form that submits to post_to_slack' do
      expect(rendered).to have_css("form[action*='post_to_slack']")
    end
  end

  context 'when organization already has notification sent' do
    let(:kudos_channel) { create(:third_party_object, :slack_channel, organization: company, third_party_id: 'C123456') }
    
    before do
      company.kudos_channel_id = kudos_channel.third_party_id
      company.save!
      assign(:kudos_channel_organizations, [{
        organization: company,
        channel: kudos_channel,
        display_name: "#{company.display_name} - #{kudos_channel.display_name}",
        already_sent: true
      }])
      render
    end

    it 'disables radio button for already-sent organization' do
      expect(rendered).to have_css('input[type="radio"][disabled]')
      expect(rendered).to include('Already sent')
    end
  end

  context 'when no kudos channels are configured' do
    before do
      assign(:kudos_channel_organizations, [])
      render
    end

    it 'displays info message about no channels' do
      expect(rendered).to include('No kudos channels configured')
      expect(rendered).to have_link('Configure kudos channels')
    end

    it 'disables Send Now button' do
      expect(rendered).to have_css('input[type="submit"][disabled][value="Send Now"]')
    end
  end
end

