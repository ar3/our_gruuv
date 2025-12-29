require 'rails_helper'

RSpec.  describe 'organizations/observations/show', type: :view do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person, first_name: 'Observer', last_name: 'Person') }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee_person) { create(:person, first_name: 'Observed', last_name: 'Person') }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: company) }
  let(:observation) do
    obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_company)
    obs.observees.build(teammate: observee_teammate)
    obs.save!
    obs.publish!
    obs
  end

  describe 'observation trigger display' do
    context 'when observation has a trigger' do
      let(:trigger) { create(:observation_trigger, trigger_source: 'slack', trigger_type: 'slack_command') }
      let(:observation_with_trigger) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_company, observation_trigger: trigger)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
        obs
      end

      before do
        assign(:organization, company)
        assign(:observation, observation_with_trigger)
        
        allow(view).to receive(:policy) do |obj|
          if obj == observation_with_trigger
            double(
              post_to_slack?: true,
              publish?: false,
              view_permalink?: false,
              update?: false
            )
          else
            double(post_to_slack?: false, update?: false, view_permalink?: false)
          end
        end
        
        allow(view).to receive(:organization_observations_path).and_return("/organizations/#{company.id}/observations")
        allow(view).to receive(:share_publicly_organization_observation_path).and_return("/organizations/#{company.id}/observations/#{observation_with_trigger.id}/share_publicly")
        allow(view).to receive(:share_privately_organization_observation_path).and_return("/organizations/#{company.id}/observations/#{observation_with_trigger.id}/share_privately")
        allow(view).to receive(:organization_observation_path).and_return("/organizations/#{company.id}/observations/#{observation_with_trigger.id}")
        
        allow_any_instance_of(Observation).to receive(:decorate).and_return(
          double(
            story_html: '<p>Test story</p>',
            gifs_html: '',
            visibility_text: 'Public to Company',
            visibility_text_style: 'text-primary',
            visibility_icon: '<i class="bi bi-people"></i>',
            feelings_display_html: '',
            permalink_url: "https://example.com/observations/#{observation_with_trigger.id}"
          )
        )
        
        allow(view).to receive(:render_markdown).and_return('<p>Formatted markdown</p>')
      end

      it 'displays trigger information' do
        render
        expect(rendered).to have_content('Story was triggered from Slack\'s Slack command')
        expect(rendered).to have_css('i.bi-info-circle')
      end
    end

    context 'when observation has no trigger' do
      before do
        assign(:organization, company)
        assign(:observation, observation)
        
        allow(view).to receive(:policy) do |obj|
          if obj == observation
            double(
              post_to_slack?: true,
              publish?: false,
              view_permalink?: false,
              update?: false
            )
          else
            double(post_to_slack?: false, update?: false, view_permalink?: false)
          end
        end
        
        allow(view).to receive(:organization_observations_path).and_return("/organizations/#{company.id}/observations")
        allow(view).to receive(:share_publicly_organization_observation_path).and_return("/organizations/#{company.id}/observations/#{observation.id}/share_publicly")
        allow(view).to receive(:share_privately_organization_observation_path).and_return("/organizations/#{company.id}/observations/#{observation.id}/share_privately")
        allow(view).to receive(:organization_observation_path).and_return("/organizations/#{company.id}/observations/#{observation.id}")
        
        allow_any_instance_of(Observation).to receive(:decorate).and_return(
          double(
            story_html: '<p>Test story</p>',
            gifs_html: '',
            visibility_text: 'Public to Company',
            visibility_text_style: 'text-primary',
            visibility_icon: '<i class="bi bi-people"></i>',
            feelings_display_html: '',
            permalink_url: "https://example.com/observations/#{observation.id}"
          )
        )
      end

      it 'does not display trigger information' do
        render
        expect(rendered).not_to have_content('Story was triggered from')
      end
    end
  end

  before do
    observer_teammate # Ensure observer teammate is created
    assign(:organization, company)
    assign(:observation, observation)
    
    # Mock policy - return different doubles based on what's being checked
    allow(view).to receive(:policy) do |obj|
      if obj == observation
        double(
          post_to_slack?: true,
          publish?: false,
          view_permalink?: false,
          update?: false
        )
      else
        double(post_to_slack?: false, update?: false, view_permalink?: false)
      end
    end
    
    # Mock route helpers
    allow(view).to receive(:organization_observations_path).and_return("/organizations/#{company.id}/observations")
    allow(view).to receive(:share_publicly_organization_observation_path).and_return("/organizations/#{company.id}/observations/#{observation.id}/share_publicly")
    allow(view).to receive(:share_privately_organization_observation_path).and_return("/organizations/#{company.id}/observations/#{observation.id}/share_privately")
    allow(view).to receive(:organization_observation_path).and_return("/organizations/#{company.id}/observations/#{observation.id}")
    
    # Mock decorator methods
    allow_any_instance_of(Observation).to receive(:decorate).and_return(
      double(
        story_html: '<p>Test story</p>',
        gifs_html: '',
        visibility_text_style: 'text-info',
        visibility_icon: '👁️',
        visibility_text: 'Public to Company',
        feelings_display_html: '<span>Happy</span>',
        permalink_url: 'https://example.com/permalink'
      )
    )
    
    # Mock format_ratings_by_type_and_level
    allow(observation).to receive(:format_ratings_by_type_and_level).and_return([])
  end

  describe 'notifications section' do
    context 'when user is observer and observation is public' do
      before do
        render
      end

      it 'displays Send Public and Send Private buttons' do
        expect(rendered).to have_link('Send Public')
        expect(rendered).to have_link('Send Private')
      end

      it 'links Send Public button to share_publicly path' do
        expect(rendered).to have_link('Send Public', href: "/organizations/#{company.id}/observations/#{observation.id}/share_publicly")
      end

      it 'links Send Private button to share_privately path' do
        expect(rendered).to have_link('Send Private', href: "/organizations/#{company.id}/observations/#{observation.id}/share_privately")
      end
    end

    context 'when user is not observer' do
      before do
        allow(view).to receive(:policy) do |obj|
          double(post_to_slack?: false, update?: false, view_permalink?: false)
        end
        render
      end

      it 'disables both buttons with warning icons' do
        expect(rendered).to have_css('button.btn-outline-secondary.disabled[disabled]', text: 'Send Public')
        expect(rendered).to have_css('button.btn-outline-secondary.disabled[disabled]', text: 'Send Private')
        expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning', count: 2)
      end
    end

    context 'when observation is journal (observer_only)' do
      let(:journal_observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :observer_only)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
        obs
      end

      before do
        assign(:observation, journal_observation)
        render
      end

      it 'disables both buttons with warning icons' do
        expect(rendered).to have_css('button.btn-outline-secondary.disabled[disabled]', text: 'Send Public')
        expect(rendered).to have_css('button.btn-outline-secondary.disabled[disabled]', text: 'Send Private')
        expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning', count: 2)
      end
    end

    context 'when observation is not public' do
      let(:private_observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :observed_only)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
        obs
      end

      before do
        assign(:observation, private_observation)
        # Ensure policy allows post_to_slack for observer
        allow(view).to receive(:policy) do |obj|
          if obj == private_observation
            double(
              post_to_slack?: true,
              publish?: false,
              view_permalink?: false,
              update?: false
            )
          else
            double(post_to_slack?: false, update?: false, view_permalink?: false)
          end
        end
        render
      end

      it 'disables Send Public button with warning icon' do
        expect(rendered).to have_css('button.btn-outline-secondary.disabled[disabled]', text: 'Send Public')
        expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning')
      end

      it 'enables Send Private button' do
        expect(rendered).to have_link('Send Private')
      end
    end

    context 'when observation is a draft' do
      let(:draft_observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_company, published_at: nil)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs
      end

      before do
        assign(:observation, draft_observation)
        # Ensure policy allows post_to_slack for observer
        allow(view).to receive(:policy) do |obj|
          if obj == draft_observation
            double(
              post_to_slack?: true,
              publish?: false,
              view_permalink?: false,
              update?: false
            )
          else
            double(post_to_slack?: false, update?: false, view_permalink?: false)
          end
        end
        render
      end

      it 'disables both buttons with warning icons' do
        expect(rendered).to have_css('button.btn-outline-secondary.disabled[disabled]', text: 'Send Public')
        expect(rendered).to have_css('button.btn-outline-secondary.disabled[disabled]', text: 'Send Private')
        expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning', count: 2)
      end

      it 'shows tooltip explaining draft observations cannot be shared' do
        expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning[data-bs-toggle="tooltip"][data-bs-title="Draft observations cannot be shared"]', count: 2)
      end
    end

    context 'when public notifications exist' do
      let(:kudos_channel) { create(:third_party_object, :slack_channel, organization: company, third_party_id: 'C123456', display_name: 'kudos') }
      let!(:public_notification) do
        Notification.create!(
          notifiable: observation,
          notification_type: 'observation_channel',
          status: 'sent_successfully',
          metadata: {
            'channel' => kudos_channel.third_party_id,
            'organization_id' => company.id.to_s,
            'is_main_message' => 'true'
          },
          message_id: '1234567890.123456'
        )
      end

      before do
        company.kudos_channel_id = kudos_channel.third_party_id
        company.save!
        # Mock slack_url
        allow_any_instance_of(Notification).to receive(:slack_url).and_return('https://slack.com/archives/C123456/p1234567890123456')
        render
      end

      it 'displays public notifications section' do
        expect(rendered).to include('Public Notifications')
        expect(rendered).to include(company.display_name)
      end

      it 'displays link to Slack message' do
        expect(rendered).to have_link('View Message', href: 'https://slack.com/archives/C123456/p1234567890123456')
      end
    end

    context 'when private notifications exist' do
      let!(:private_notification) do
        Notification.create!(
          notifiable: observation,
          notification_type: 'observation_dm',
          status: 'sent_successfully',
          metadata: { 'channel' => 'U789012' },
          message_id: '9876543210.987654',
          created_at: 1.day.ago
        )
      end

      before do
        # Mock slack_url
        allow_any_instance_of(Notification).to receive(:slack_url).and_return('https://slack.com/archives/D123456/p9876543210987654')
        render
      end

      it 'displays private notifications section' do
        expect(rendered).to include('Private Notifications')
        expect(rendered).to include('Shared privately on')
      end

      it 'displays link to Slack message' do
        expect(rendered).to have_link('View Message', href: 'https://slack.com/archives/D123456/p9876543210987654')
      end

      it 'groups notifications by date' do
        # Should show date once for grouped notifications
        expect(rendered.scan(/Shared privately on/).count).to eq(1)
      end
    end
  end
end

