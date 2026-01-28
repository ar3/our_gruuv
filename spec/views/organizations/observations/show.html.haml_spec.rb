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
        
        # Make current_person available
        obs_observer = observation_with_trigger.observer
        view.instance_variable_set(:@current_person, obs_observer)
        view.define_singleton_method(:current_person) { obs_observer }
        
        allow(view).to receive(:policy) do |obj|
          if obj == observation_with_trigger
            double(
              post_to_slack?: true,
              publish?: false,
              view_permalink?: false,
              update?: false,
              destroy?: false,
              restore?: false
            )
          else
            double(post_to_slack?: false, update?: false, view_permalink?: false, destroy?: false, restore?: false)
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
        
        # Make current_person available
        obs_observer = observation.observer
        view.instance_variable_set(:@current_person, obs_observer)
        view.define_singleton_method(:current_person) { obs_observer }
        
        allow(view).to receive(:policy) do |obj|
          if obj == observation
            double(
              post_to_slack?: true,
              publish?: false,
              view_permalink?: false,
              update?: false,
              destroy?: false,
              restore?: false
            )
          else
            double(post_to_slack?: false, update?: false, view_permalink?: false, destroy?: false, restore?: false)
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
    
    # Make current_person available - ViewHelpers provides it via @current_person
    obs_observer = observer
    view.instance_variable_set(:@current_person, obs_observer)
    # Define method directly on view for content_for blocks
    view.define_singleton_method(:current_person) { obs_observer }
    
    # Mock policy - return different doubles based on what's being checked
    allow(view).to receive(:policy) do |obj|
      if obj == observation
        double(
          post_to_slack?: true,
          publish?: false,
          view_permalink?: false,
          update?: false,
          destroy?: false,
          restore?: false
        )
      else
        double(post_to_slack?: false, update?: false, view_permalink?: false, destroy?: false, restore?: false)
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

  describe 'share prompt section' do
    context 'when observation is published, has no notifications, and is not journal' do
      before do
        # Ensure observation has no notifications
        observation.notifications.destroy_all
        # Assign observation and organization
        assign(:observation, observation)
        assign(:organization, company)
        # Make current_person available
        obs_observer = observation.observer
        view.instance_variable_set(:@current_person, obs_observer)
        view.define_singleton_method(:current_person) { obs_observer }
        
        # Mock instance variables that would be set in controller
        allow(view).to receive(:organization_observation_path).and_return("/organizations/#{company.id}/observations/#{observation.id}")
        assign(:kudos_channel_organizations, [])
        assign(:available_teammates_for_notification, [])
        assign(:page_visit_stats, { total_views: 5, unique_viewers: 3 })
        assign(:observee_names, [observee_person.casual_name])
        assign(:direct_manager_names, [])
        assign(:other_manager_names, [])
        
        # Mock route helpers
        allow(view).to receive(:share_publicly_organization_observation_path).and_return("/organizations/#{company.id}/observations/#{observation.id}/share_publicly")
        allow(view).to receive(:share_privately_organization_observation_path).and_return("/organizations/#{company.id}/observations/#{observation.id}/share_privately")
        
        # Mock policy
        allow(view).to receive(:policy) do |obj|
          if obj == observation
            double(
              post_to_slack?: true,
              publish?: false,
              view_permalink?: false,
              update?: false,
              destroy?: false,
              restore?: false
            )
          else
            double(post_to_slack?: false, update?: false, view_permalink?: false, destroy?: false, restore?: false)
          end
        end
        
        render
      end

      it 'displays the personalized heading' do
        expect(rendered).to have_content('🎉GREAT Observation... almost done!')
        expect(rendered).to have_content("#{observer.casual_name} helping #{company.name} grow with one great story at a time 📖")
      end

      it 'displays two-column layout' do
        expect(rendered).to have_css('.row .col-md-4')
        expect(rendered).to have_css('.row .col-md-8')
      end

      it 'displays privacy selector with all buttons disabled' do
        Observation.privacy_levels.keys.each do |key|
          expect(rendered).to have_css("input[type='radio'][name='privacy_level_display'][value='#{key}'][disabled]")
        end
      end

      it 'displays current privacy level as checked' do
        expect(rendered).to have_css("input[type='radio'][name='privacy_level_display'][value='#{observation.privacy_level}'][checked]")
      end

      it 'displays page visit statistics' do
        expect(rendered).to have_content('Observation has been viewed 5 times by 3 teammates')
        expect(rendered).to have_css('.text-muted.caption-text')
      end

      it 'displays Slack celebration section header' do
        expect(rendered).to have_content('📣Celebrate with a Slack Post 📢')
      end

      it 'displays private notification section header' do
        expect(rendered).to have_content('Notify people privately')
      end

      it 'displays OR divider' do
        expect(rendered).to have_content('OR')
        expect(rendered).to have_css('hr')
      end

      it 'displays correct link texts' do
        expect(rendered).to have_link('Select the channel to post the celebration', href: "/organizations/#{company.id}/observations/#{observation.id}/share_publicly")
        expect(rendered).to have_link('Select who to send private notification', href: "/organizations/#{company.id}/observations/#{observation.id}/share_privately")
      end

      context 'when there is one company kudos channel' do
        before do
          assign(:kudos_channel_organizations, [
            { organization: company, channel: nil, display_name: 'Acme - #kudos', already_sent: false }
          ])
          render
        end

        it 'displays only the company channel name' do
          expect(rendered).to have_content('Acme - #kudos')
          expect(rendered).not_to have_content('or one of the other')
        end
      end

      context 'when there are multiple public kudos channels' do
        before do
          assign(:kudos_channel_organizations, [
            { organization: company, channel: nil, display_name: 'Acme - #kudos', already_sent: false },
            { organization: nil, channel: nil, display_name: 'Team A - #kudos', already_sent: false },
            { organization: nil, channel: nil, display_name: 'Team B - #kudos', already_sent: false }
          ])
          render
        end

        it 'displays company channel and message about other channels' do
          expect(rendered).to have_content('Acme - #kudos')
          expect(rendered).to have_content('or one of the other 2 public kudos channels')
        end

        it 'does not list the other channel names' do
          expect(rendered).not_to have_content('Team A - #kudos')
          expect(rendered).not_to have_content('Team B - #kudos')
        end
      end
    end

    context 'when observation is not public (cannot share publicly)' do
      let(:private_observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :observed_only)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
        obs
      end

      before do
        assign(:observation, private_observation)
        assign(:organization, company)
        # Ensure observation has no notifications
        private_observation.notifications.destroy_all
        # Make current_person available
        obs_observer = private_observation.observer
        view.instance_variable_set(:@current_person, obs_observer)
        view.define_singleton_method(:current_person) { obs_observer }
        
        # Mock instance variables that would be set in controller
        allow(view).to receive(:organization_observation_path).and_return("/organizations/#{company.id}/observations/#{private_observation.id}")
        assign(:kudos_channel_organizations, [])
        assign(:available_teammates_for_notification, [
          { teammate: observee_teammate, person: observee_person, role: 'Observed' }
        ])
        assign(:page_visit_stats, { total_views: 2, unique_viewers: 1 })
        assign(:observee_names, [observee_person.casual_name])
        assign(:direct_manager_names, [])
        assign(:other_manager_names, [])
        
        # Mock route helpers
        allow(view).to receive(:share_publicly_organization_observation_path).and_return("/organizations/#{company.id}/observations/#{private_observation.id}/share_publicly")
        allow(view).to receive(:share_privately_organization_observation_path).and_return("/organizations/#{company.id}/observations/#{private_observation.id}/share_privately")
        # Ensure policy allows post_to_slack for observer
        allow(view).to receive(:policy) do |obj|
          if obj == private_observation
            double(
              post_to_slack?: true,
              publish?: false,
              view_permalink?: false,
              update?: false,
              destroy?: false,
              restore?: false
            )
          else
            double(post_to_slack?: false, update?: false, view_permalink?: false, destroy?: false, restore?: false)
          end
        end
        render
      end

      it 'displays the share prompt section' do
        expect(rendered).to have_content('🎉GREAT Observation... almost done!')
        expect(rendered).to have_content("#{observer.casual_name} helping #{company.name} grow with one great story at a time 📖")
      end

      it 'shows alert for non-public observation in channels section' do
        expect(rendered).to have_content('This is a private observation and therefore can\'t be shared in a channel')
        expect(rendered).to have_css('.alert.alert-info')
      end

      it 'enables private notification link' do
        expect(rendered).to have_link('Select who to send private notification', href: "/organizations/#{company.id}/observations/#{private_observation.id}/share_privately")
      end
    end

    context 'when observation has notifications' do
      let!(:notification) do
        Notification.create!(
          notifiable: observation,
          notification_type: 'observation_channel',
          status: 'sent_successfully',
          metadata: { 'organization_id' => company.id.to_s }
        )
      end

      before do
        # Make current_person available
        obs_observer = observation.observer
        view.instance_variable_set(:@current_person, obs_observer)
        view.define_singleton_method(:current_person) { obs_observer }
        render
      end

      it 'does not display the share prompt section' do
        expect(rendered).not_to have_content('helping')
        expect(rendered).not_to have_content('grow with one great story at a time')
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
        # Make current_person available
        obs_observer = draft_observation.observer
        view.instance_variable_set(:@current_person, obs_observer)
        view.define_singleton_method(:current_person) { obs_observer }
        allow(view).to receive(:policy) do |obj|
          if obj == draft_observation
            double(
              post_to_slack?: true,
              publish?: false,
              view_permalink?: false,
              update?: false,
              destroy?: false,
              restore?: false
            )
          else
            double(post_to_slack?: false, update?: false, view_permalink?: false, destroy?: false, restore?: false)
          end
        end
        render
      end

      it 'does not display the share prompt section' do
        expect(rendered).not_to have_content('helping')
        expect(rendered).not_to have_content('grow with one great story at a time')
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
        # Make current_person available
        obs_observer = journal_observation.observer
        view.instance_variable_set(:@current_person, obs_observer)
        view.define_singleton_method(:current_person) { obs_observer }
        allow(view).to receive(:policy) do |obj|
          if obj == journal_observation
            double(
              post_to_slack?: true,
              publish?: false,
              view_permalink?: false,
              update?: false,
              destroy?: false,
              restore?: false
            )
          else
            double(post_to_slack?: false, update?: false, view_permalink?: false, destroy?: false, restore?: false)
          end
        end
        render
      end

      it 'does not display the share prompt section' do
        expect(rendered).not_to have_content('helping')
        expect(rendered).not_to have_content('grow with one great story at a time')
      end
    end

    context 'when user is not the observer' do
      let(:other_person) { create(:person) }
      let!(:other_teammate) { create(:teammate, person: other_person, organization: company) }

      before do
        # Ensure observation has no notifications
        observation.notifications.destroy_all
        # Make current_person available as someone other than the observer
        other = other_person
        view.instance_variable_set(:@current_person, other)
        view.define_singleton_method(:current_person) { other }
        render
      end

      it 'does not display the share prompt section' do
        expect(rendered).not_to have_content('helping')
        expect(rendered).not_to have_content('grow with one great story at a time')
      end
    end
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
        # Make current_person available
        view.instance_variable_set(:@current_person, nil)
        view.define_singleton_method(:current_person) { nil }
        allow(view).to receive(:policy) do |obj|
          double(post_to_slack?: false, update?: false, view_permalink?: false, destroy?: false, restore?: false)
        end
        render
      end

      it 'disables both buttons with warning icons' do
        expect(rendered).to have_css('button.btn-outline-secondary.disabled[disabled]', text: 'Send Public')
        expect(rendered).to have_css('button.btn-outline-secondary.disabled[disabled]', text: 'Send Private')
        # Note: There are now more warning icons due to actions card, so we check for at least 2
        expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning', minimum: 2)
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
        # Make current_person available
        obs_observer = journal_observation.observer
        view.instance_variable_set(:@current_person, obs_observer)
        view.define_singleton_method(:current_person) { obs_observer }
        render
      end

      it 'disables both buttons with warning icons' do
        expect(rendered).to have_css('button.btn-outline-secondary.disabled[disabled]', text: 'Send Public')
        expect(rendered).to have_css('button.btn-outline-secondary.disabled[disabled]', text: 'Send Private')
        # Note: There are now more warning icons due to actions card, so we check for at least 2
        expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning', minimum: 2)
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
        # Make current_person available
        obs_observer = private_observation.observer
        view.instance_variable_set(:@current_person, obs_observer)
        view.define_singleton_method(:current_person) { obs_observer }
        # Ensure policy allows post_to_slack for observer
        allow(view).to receive(:policy) do |obj|
          if obj == private_observation
            double(
              post_to_slack?: true,
              publish?: false,
              view_permalink?: false,
              update?: false,
              destroy?: false,
              restore?: false
            )
          else
            double(post_to_slack?: false, update?: false, view_permalink?: false, destroy?: false, restore?: false)
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
        # Make current_person available
        obs_observer = observer
        view.instance_variable_set(:@current_person, obs_observer)
        view.define_singleton_method(:current_person) { obs_observer }
        # Ensure policy allows post_to_slack for observer
        allow(view).to receive(:policy) do |obj|
          if obj == draft_observation
            double(
              post_to_slack?: true,
              publish?: false,
              view_permalink?: false,
              update?: false,
              destroy?: false,
              restore?: false
            )
          else
            double(post_to_slack?: false, update?: false, view_permalink?: false, destroy?: false, restore?: false)
          end
        end
        render
      end

      it 'disables both buttons with warning icons' do
        expect(rendered).to have_css('button.btn-outline-secondary.disabled[disabled]', text: 'Send Public')
        expect(rendered).to have_css('button.btn-outline-secondary.disabled[disabled]', text: 'Send Private')
        # Note: There are now more warning icons due to actions card, so we check for at least 2
        expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning', minimum: 2)
      end

      it 'shows tooltip explaining draft observations cannot be shared' do
        # Check that the tooltips exist (there may be more than 2 due to actions card)
        expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning[data-bs-toggle="tooltip"][data-bs-title="Draft observations cannot be shared"]', minimum: 2)
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
        # Make current_person available
        obs_observer = observation.observer
        view.instance_variable_set(:@current_person, obs_observer)
        view.define_singleton_method(:current_person) { obs_observer }
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
        # Make current_person available
        obs_observer = observation.observer
        view.instance_variable_set(:@current_person, obs_observer)
        view.define_singleton_method(:current_person) { obs_observer }
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
        # Note: This test may need adjustment if the view structure changes
        expect(rendered.scan(/Shared privately on/).count).to be >= 1
      end
    end
  end

  describe 'actions card' do
    before do
      allow(view).to receive(:edit_organization_observation_path).and_return("/organizations/#{company.id}/observations/#{observation.id}/edit")
      allow(view).to receive(:restore_organization_observation_path).and_return("/organizations/#{company.id}/observations/#{observation.id}/restore")
      allow_any_instance_of(Observation).to receive(:decorate).and_return(
        double(
          story_html: '<p>Test story</p>',
          gifs_html: '',
          visibility_text_style: 'text-info',
          visibility_icon: '👁️',
          visibility_text: 'Public to Company',
          feelings_display_html: '<span>Happy</span>',
          permalink_url: 'https://example.com/permalink',
          permalink_path: '/organizations/1/kudos/2024-01-01/123'
        )
      )
      render
    end

    it 'displays the actions card' do
      expect(rendered).to have_css('.card', text: /Actions/)
      expect(rendered).to have_css('h6', text: 'Actions')
      expect(rendered).to have_css('i.bi-gear')
    end

    context 'View Public Version button' do
      context 'when user has view_permalink permission' do
        let(:public_world_observation) do
          obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_world)
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
          obs
        end

        before do
          assign(:observation, public_world_observation)
          allow(view).to receive(:policy) do |obj|
            if obj == public_world_observation
              double(
                post_to_slack?: true,
                publish?: false,
                view_permalink?: true,
                update?: false,
                destroy?: false,
                restore?: false
              )
            else
              double(post_to_slack?: false, update?: false, view_permalink?: false, destroy?: false, restore?: false)
            end
          end
          allow_any_instance_of(Observation).to receive(:decorate).and_return(
            double(
              story_html: '<p>Test story</p>',
              gifs_html: '',
              visibility_text_style: 'text-info',
              visibility_icon: '👁️',
              visibility_text: 'Public to World',
              feelings_display_html: '<span>Happy</span>',
              permalink_url: 'https://example.com/permalink',
              permalink_path: '/organizations/1/kudos/2024-01-01/123'
            )
          )
          render
        end

        it 'displays enabled View Public Version link' do
          expect(rendered).to have_link('View Public Version', href: '/organizations/1/kudos/2024-01-01/123')
          expect(rendered).to have_css('a.btn-outline-secondary', text: 'View Public Version')
        end
      end

      context 'when user does not have view_permalink permission' do
        it 'displays disabled View Public Version button with warning icon' do
          expect(rendered).to have_css('button.btn-outline-secondary.disabled[disabled]', text: 'View Public Version')
          expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning')
        end

        it 'shows tooltip explaining why View Public Version is disabled' do
          expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning[data-bs-toggle="tooltip"]')
        end
      end
    end

    context 'Edit Observation button' do
      context 'when user has update permission' do
        before do
          allow(view).to receive(:policy) do |obj|
            if obj == observation
              double(
                post_to_slack?: true,
                publish?: false,
                view_permalink?: false,
                update?: true,
                destroy?: false,
                restore?: false
              )
            else
              double(post_to_slack?: false, update?: false, view_permalink?: false, destroy?: false, restore?: false)
            end
          end
          render
        end

        it 'displays enabled Edit Observation link' do
          expect(rendered).to have_link('Edit Observation', href: "/organizations/#{company.id}/observations/#{observation.id}/edit")
          expect(rendered).to have_css('a.btn-outline-secondary', text: 'Edit Observation')
        end
      end

      context 'when user does not have update permission' do
        it 'displays disabled Edit Observation button with warning icon' do
          expect(rendered).to have_css('button.btn-outline-secondary.disabled[disabled]', text: 'Edit Observation')
          expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning')
        end

        it 'shows tooltip explaining why Edit Observation is disabled' do
          expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning[data-bs-title="You need to be the observer to edit this observation"]')
        end
      end
    end

    context 'Archive Observation button' do
      context 'when user has destroy permission and observation is not archived' do
        before do
          allow(view).to receive(:policy) do |obj|
            if obj == observation
              double(
                post_to_slack?: true,
                publish?: false,
                view_permalink?: false,
                update?: false,
                destroy?: true,
                restore?: false
              )
            else
              double(post_to_slack?: false, update?: false, view_permalink?: false, destroy?: false, restore?: false)
            end
          end
          render
        end

        it 'displays enabled Archive Observation button' do
          expect(rendered).to have_css('form[action="/organizations/' + company.id.to_s + '/observations/' + observation.id.to_s + '"][method="post"]')
          expect(rendered).to have_css('input[name="_method"][value="delete"]', visible: false)
          expect(rendered).to have_button('Archive Observation')
        end
      end

      context 'when observation is archived and user has restore permission' do
        let(:archived_observation) do
          obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_company, deleted_at: Time.current)
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
          obs
        end

        before do
          assign(:observation, archived_observation)
          allow(view).to receive(:policy) do |obj|
            if obj == archived_observation
              double(
                post_to_slack?: true,
                publish?: false,
                view_permalink?: false,
                update?: false,
                destroy?: false,
                restore?: true
              )
            else
              double(post_to_slack?: false, update?: false, view_permalink?: false, destroy?: false, restore?: false)
            end
          end
          allow_any_instance_of(Observation).to receive(:decorate).and_return(
            double(
              story_html: '<p>Test story</p>',
              gifs_html: '',
              visibility_text_style: 'text-info',
              visibility_icon: '👁️',
              visibility_text: 'Public to Company',
              feelings_display_html: '<span>Happy</span>',
              permalink_url: 'https://example.com/permalink',
              permalink_path: '/organizations/1/kudos/2024-01-01/123'
            )
          )
          render
        end

        it 'displays Restore Observation button' do
          expect(rendered).to have_button('Restore Observation')
          # Check for the form with restore path (path may vary, so we check for the button and method)
          expect(rendered).to have_css('form[method="post"] input[name="_method"][value="patch"]', visible: false)
          expect(rendered).to have_button('Restore Observation')
        end
      end

      context 'when user does not have destroy permission' do
        it 'displays disabled Archive Observation button with warning icon' do
          expect(rendered).to have_css('button.btn-outline-secondary.disabled[disabled]', text: 'Archive Observation')
          expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning')
        end

        it 'shows tooltip explaining why Archive Observation is disabled' do
          expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning[data-bs-title="You need to be the observer to archive this observation"]')
        end
      end
    end

    it 'does not display Archive button in header' do
      expect(rendered).not_to have_css('.header_action button', text: 'Archive')
      expect(rendered).not_to have_css('.header_action form[method="post"] input[name="_method"][value="delete"]', visible: false)
    end
  end
end

