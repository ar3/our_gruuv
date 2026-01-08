require 'rails_helper'

RSpec.describe Observations::PostNotificationJob, type: :job do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee_person) { create(:person) }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: company) }
  let(:observation) do
    obs = build(:observation, observer: observer, company: company, privacy_level: :observed_only)
    obs.observees.build(teammate: observee_teammate)
    obs.save!
    create(:observation_rating, observation: obs, rateable: create(:ability, organization: company), rating: :strongly_agree)
    obs
  end

  let(:slack_service) { double('SlackService') }

  before do
    observer_teammate # Ensure observer teammate is created
    # Create Slack identities for the teammates
    create(:teammate_identity, teammate: observer_teammate, provider: 'slack', uid: 'U123456')
    create(:teammate_identity, teammate: observee_teammate, provider: 'slack', uid: 'U789012')

    # Mock SlackService to avoid Slack configuration requirements
    allow(SlackService).to receive(:new).and_return(slack_service)
    allow(slack_service).to receive(:post_message) do |notification_id|
      notification = Notification.find(notification_id)
      notification.update!(status: 'sent_successfully', message_id: '1234567890.123456')
      { success: true, message_id: '1234567890.123456' }
    end
    allow(slack_service).to receive(:open_or_create_group_dm) do |user_ids:|
      { success: true, channel_id: 'D1234567890' }
    end
  end

  describe '#perform' do
    context 'when sending DMs' do
      let(:notify_teammate_ids) { [observee_teammate.id.to_s] }

      it 'creates main message and thread reply notifications' do
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids)
        }.to change(Notification, :count).by(2) # Main message + thread reply
      end

      it 'includes observer in group DM when observer has Slack configured' do
        job = Observations::PostNotificationJob.new
        job.perform(observation.id, notify_teammate_ids)

        main_notification = Notification.where(notification_type: 'observation_dm')
                                       .where("metadata->>'is_thread_reply' != 'true' OR metadata->>'is_thread_reply' IS NULL")
                                       .first
        expect(main_notification).to be_present
        expect(main_notification.notification_type).to eq('observation_dm')
        expect(main_notification.status).to eq('sent_successfully')
        # Should be a group DM since observer is included
        expect(main_notification.metadata['is_group_dm']).to eq(true)
        # Should include both observee and observer IDs (stored as array, may be strings or integers)
        teammate_ids = main_notification.metadata['teammate_ids']
        expect(teammate_ids.map(&:to_i)).to include(observee_teammate.id)
        expect(teammate_ids.map(&:to_i)).to include(observer_teammate.id)
      end

      it 'sends individual DM to observer when only observer has Slack configured' do
        # Remove observee's Slack identity
        observee_teammate.teammate_identities.destroy_all

        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids)
        }.to change(Notification, :count).by(2) # Main message + thread reply to observer

        main_notification = Notification.where(notification_type: 'observation_dm')
                                       .where("metadata->>'is_thread_reply' != 'true' OR metadata->>'is_thread_reply' IS NULL")
                                       .first
        expect(main_notification).to be_present
        expect(main_notification.metadata['channel']).to eq(observer_teammate.slack_user_id)
        expect(main_notification.metadata['is_group_dm']).to eq(false)
        # Should only include observer ID (stored as array, may be strings or integers)
        teammate_ids = main_notification.metadata['teammate_ids']
        expect(teammate_ids.map(&:to_i)).to eq([observer_teammate.id])
      end

      it 'sends group DM when observer is already in the list without duplicating' do
        # Include observer in the teammate_ids
        notify_teammate_ids_with_observer = [observee_teammate.id.to_s, observer_teammate.id.to_s]

        job = Observations::PostNotificationJob.new
        job.perform(observation.id, notify_teammate_ids_with_observer)

        main_notification = Notification.where(notification_type: 'observation_dm')
                                       .where("metadata->>'is_thread_reply' != 'true' OR metadata->>'is_thread_reply' IS NULL")
                                       .first
        expect(main_notification).to be_present
        expect(main_notification.metadata['is_group_dm']).to eq(true)
        # Should not duplicate observer ID (stored as array, may be strings or integers)
        teammate_ids = main_notification.metadata['teammate_ids']
        teammate_ids_as_ints = teammate_ids.map(&:to_i)
        expect(teammate_ids_as_ints).to include(observer_teammate.id)
        expect(teammate_ids_as_ints).to include(observee_teammate.id)
        expect(teammate_ids_as_ints.count(observer_teammate.id)).to eq(1)
      end

      it 'creates thread reply notification' do
        job = Observations::PostNotificationJob.new
        job.perform(observation.id, notify_teammate_ids)

        thread_notification = Notification.where(notification_type: 'observation_dm')
                                          .where("metadata->>'is_thread_reply' = 'true'")
                                          .first
        expect(thread_notification).to be_present
        expect(thread_notification.main_thread).to be_present
        expect(thread_notification.status).to eq('sent_successfully')
      end

      it 'skips observees without Slack user ID but still includes observer if they have Slack' do
        observee_teammate.teammate_identities.destroy_all # Remove Slack identity

        # Observer still has Slack, so should send individual DM to observer
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids)
        }.to change(Notification, :count).by(2) # Main message + thread reply to observer

        main_notification = Notification.where(notification_type: 'observation_dm')
                                       .where("metadata->>'is_thread_reply' != 'true' OR metadata->>'is_thread_reply' IS NULL")
                                       .first
        expect(main_notification.metadata['channel']).to eq(observer_teammate.slack_user_id)
        expect(main_notification.metadata['is_group_dm']).to eq(false)
      end

      it 'handles Slack API errors gracefully by falling back to individual DMs' do
        allow(slack_service).to receive(:open_or_create_group_dm).and_return({ success: false, error: 'Slack API error' })

        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids)
        }.to change(Notification, :count).by(4) # Falls back to individual DMs: 2 for observee (main + thread) + 2 for observer (main + thread)

        # Should have created notifications for both observee and observer (fallback to individual DMs)
        notifications = Notification.where(notification_type: 'observation_dm')
        expect(notifications.count).to eq(4) # 2 for observee, 2 for observer
      end
    end

    context 'when sending to channels' do
      let(:notify_teammate_ids) { [] }
      let(:kudos_channel) { create(:third_party_object, :slack_channel, organization: company, third_party_id: 'C999999') }

      before do
        observation.update!(privacy_level: :public_to_world, published_at: Time.current)
        company.kudos_channel_id = kudos_channel.third_party_id
        company.save!
        allow(slack_service).to receive(:update_message) do |notification_id|
          notification = Notification.find(notification_id)
          notification.update!(status: 'sent_successfully', message_id: '9876543210.987654')
          { success: true, message_id: '9876543210.987654' }
        end
      end

      it 'creates notifications for kudos channel' do
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids, company.id)
        }.to change(Notification, :count).by(2) # Main message + thread reply
      end

      it 'sends to specified kudos channel' do
        job = Observations::PostNotificationJob.new
        job.perform(observation.id, notify_teammate_ids, company.id)

        main_notification = Notification.where(notification_type: 'observation_channel')
                                        .where("metadata->>'is_main_message' = 'true'")
                                        .first
        expect(main_notification).to be_present
        expect(main_notification.metadata['channel']).to eq('C999999')
        expect(main_notification.metadata['organization_id']).to eq(company.id.to_s)
      end

      it 'creates thread reply with feelings and ratings' do
        job = Observations::PostNotificationJob.new
        job.perform(observation.id, notify_teammate_ids, company.id)

        thread_notification = Notification.where(notification_type: 'observation_channel')
                                          .where("metadata->>'is_thread_reply' = 'true'")
                                          .first
        expect(thread_notification).to be_present
        expect(thread_notification.main_thread).to be_present
      end

      it 'handles Slack API errors for channels' do
        allow(slack_service).to receive(:post_message).and_raise(StandardError.new('Channel error'))

        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids, company.id)
        }.to change(Notification, :count).by(1) # Main message created, but posting fails
      end

      it 'does not post if observation is not public' do
        observation.update!(privacy_level: :observed_only)

        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids, company.id)
        }.not_to change(Notification, :count)
      end

      it 'does not post if observation is not published' do
        observation.update!(published_at: nil)

        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids, company.id)
        }.not_to change(Notification, :count)
      end

      it 'does not post if organization has no kudos channel' do
        company.kudos_channel_id = nil
        company.save!

        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids, company.id)
        }.not_to change(Notification, :count)
      end

      it 'handles observation with nil primary_feeling gracefully' do
        observation.update!(primary_feeling: nil, secondary_feeling: nil)

        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids, company.id)
        }.to change(Notification, :count).by(2) # Main message + thread reply (without feelings)

        thread_notification = Notification.where(notification_type: 'observation_channel')
                                          .where("metadata->>'is_thread_reply' = 'true'")
                                          .first
        expect(thread_notification).to be_present
        # Should not raise error when building thread reply with nil feelings
        rich_message = thread_notification.rich_message.is_a?(String) ? JSON.parse(thread_notification.rich_message) : thread_notification.rich_message
        expect(rich_message).to be_an(Array)
      end
    end

    context 'when sending both DMs and channels' do
      let(:notify_teammate_ids) { [observee_teammate.id.to_s] }
      let(:kudos_channel) { create(:third_party_object, :slack_channel, organization: company, third_party_id: 'C999999') }

      before do
        observation.update!(privacy_level: :public_to_world, published_at: Time.current)
        company.kudos_channel_id = kudos_channel.third_party_id
        company.save!
        allow(slack_service).to receive(:update_message) do |notification_id|
          notification = Notification.find(notification_id)
          notification.update!(status: 'sent_successfully', message_id: '9876543210.987654')
          { success: true, message_id: '9876543210.987654' }
        end
      end

      it 'creates notifications for both DMs and channels' do
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids, company.id)
        }.to change(Notification, :count).by(4) # 2 DM notifications (main + thread, includes observer) + 2 channel notifications (main + thread)
      end
    end

    context 'when observation cannot post to Slack' do
      before do
        observation.update!(privacy_level: :observer_only)
        # Observer_only cannot post to channels (only public levels can)
      end

      it 'does not create any notifications' do
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, [])
        }.not_to change(Notification, :count)
      end
    end

    context 'message content' do
      let(:notify_teammate_ids) { [observee_teammate.id.to_s] }

      it 'includes observation details in DM message using channel template' do
        job = Observations::PostNotificationJob.new
        job.perform(observation.id, notify_teammate_ids)

        main_notification = Notification.where(notification_type: 'observation_dm')
                                       .where("metadata->>'is_thread_reply' != 'true' OR metadata->>'is_thread_reply' IS NULL")
                                       .first
        expect(main_notification).to be_present
        # rich_message is stored as JSON string, parse it
        rich_message = main_notification.rich_message.is_a?(String) ? JSON.parse(main_notification.rich_message) : main_notification.rich_message
        # DM messages now use same template as channel messages (context block for intro, not header)
        intro_block = rich_message.find { |block| block['type'] == 'context' }
        expect(intro_block).to be_present
        intro_text = intro_block.dig('elements', 0, 'text')
        expect(intro_text).to include('New awesome story')
        story_text = rich_message.find { |block| block['type'] == 'section' && block.dig('text', 'text')&.include?(observation.story) }&.dig('text', 'text')
        expect(story_text).to include(observation.story)
      end

      it 'includes observation details in channel message' do
        observation.update!(privacy_level: :public_to_world, published_at: Time.current)
        kudos_channel = create(:third_party_object, :slack_channel, organization: company, third_party_id: 'C999999')
        company.kudos_channel_id = kudos_channel.third_party_id
        company.save!

        job = Observations::PostNotificationJob.new
        job.perform(observation.id, [], company.id)

        main_notification = Notification.where(notification_type: 'observation_channel')
                                        .where("metadata->>'is_main_message' = 'true'")
                                        .first
        expect(main_notification).to be_present
        # rich_message is stored as JSON string, parse it
        rich_message = main_notification.rich_message.is_a?(String) ? JSON.parse(main_notification.rich_message) : main_notification.rich_message
        # Channel messages use context blocks for intro, not header blocks
        intro_block = rich_message.find { |block| block['type'] == 'context' }
        expect(intro_block).to be_present
        intro_text = intro_block.dig('elements', 0, 'text')
        expect(intro_text).to include('New awesome story')
        story_text = rich_message.find { |block| block['type'] == 'section' && block.dig('text', 'text')&.include?(observation.story) }&.dig('text', 'text')
        expect(story_text).to include(observation.story)
      end

      it 'includes ratings summary in thread reply' do
        job = Observations::PostNotificationJob.new
        job.perform(observation.id, notify_teammate_ids)

        thread_notification = Notification.where(notification_type: 'observation_dm')
                                         .where("metadata->>'is_thread_reply' = 'true'")
                                         .first
        expect(thread_notification).to be_present
        rich_message = thread_notification.rich_message.is_a?(String) ? JSON.parse(thread_notification.rich_message) : thread_notification.rich_message
        # Ratings are in the thread reply, not the main message
        # The format_ratings_by_type_and_level method formats ratings as "An Exceptional demonstration of <links>"
        ratings_blocks = rich_message.select { |block| block['type'] == 'section' }
        expect(ratings_blocks).to be_present
        # Check that at least one section block contains rating-related text
        # The format uses "Exceptional" for strongly_agree, "demonstration" for Ability
        ratings_text = ratings_blocks.map { |b| b.dig('text', 'text') }.join(' ')
        expect(ratings_text).to match(/Exceptional|demonstration|execution|example/i)
      end
    end

    context 'Slack handle and icon handling' do
      let(:notify_teammate_ids) { [] }
      let(:kudos_channel) { create(:third_party_object, :slack_channel, organization: company, third_party_id: 'C999999') }
      let(:observer_slack_identity) { observer_teammate.teammate_identities.find_by(provider: 'slack') }

      before do
        observation.update!(privacy_level: :public_to_world, published_at: Time.current)
        company.kudos_channel_id = kudos_channel.third_party_id
        company.save!
        allow(slack_service).to receive(:update_message) do |notification_id|
          notification = Notification.find(notification_id)
          notification.update!(status: 'sent_successfully', message_id: '9876543210.987654')
          { success: true, message_id: '9876543210.987654' }
        end
      end

      context 'when observer has Slack identity' do
        before do
          observer_slack_identity.update!(
            uid: 'U123456',
            name: 'Observer Slack Name',
            profile_image_url: 'https://slack.com/avatar123.png'
          )
        end

        it 'uses Slack handle in main message intro text' do
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids, company.id)

          main_notification = Notification.where(notification_type: 'observation_channel')
                                        .where("metadata->>'is_main_message' = 'true'")
                                        .first
          rich_message = main_notification.rich_message.is_a?(String) ? JSON.parse(main_notification.rich_message) : main_notification.rich_message
          
          intro_block = rich_message.find { |block| block['type'] == 'context' }
          expect(intro_block).to be_present
          intro_text = intro_block.dig('elements', 0, 'text')
          expect(intro_text).to include('<@U123456>')
          expect(intro_text).not_to include(observer.casual_name)
        end

        it 'sets username override in metadata' do
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids, company.id)

          main_notification = Notification.where(notification_type: 'observation_channel')
                                        .where("metadata->>'is_main_message' = 'true'")
                                        .first
          expect(main_notification.metadata['username']).to eq("#{observer.casual_name} via OG")
        end

        it 'uses Slack profile image as icon_url' do
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids, company.id)

          main_notification = Notification.where(notification_type: 'observation_channel')
                                        .where("metadata->>'is_main_message' = 'true'")
                                        .first
          expect(main_notification.metadata['icon_url']).to eq('https://slack.com/avatar123.png')
        end

        it 'sets username and icon_url on thread reply' do
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids, company.id)

          thread_notification = Notification.where(notification_type: 'observation_channel')
                                          .where("metadata->>'is_thread_reply' = 'true'")
                                          .first
          expect(thread_notification.metadata['username']).to eq("#{observer.casual_name} via OG")
          expect(thread_notification.metadata['icon_url']).to eq('https://slack.com/avatar123.png')
        end
      end

      context 'when observer has Slack identity but no profile image' do
        before do
          observer_slack_identity.update!(
            uid: 'U123456',
            name: 'Observer Slack Name',
            profile_image_url: nil
          )
        end

        it 'falls back to favicon for icon_url' do
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids, company.id)

          main_notification = Notification.where(notification_type: 'observation_channel')
                                        .where("metadata->>'is_main_message' = 'true'")
                                        .first
          expect(main_notification.metadata['icon_url']).to include('/favicon-32x32.png')
        end
      end

      context 'when observer has no Slack identity' do
        before do
          observer_slack_identity.destroy
        end

        it 'uses casual name in main message intro text' do
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids, company.id)

          main_notification = Notification.where(notification_type: 'observation_channel')
                                        .where("metadata->>'is_main_message' = 'true'")
                                        .first
          rich_message = main_notification.rich_message.is_a?(String) ? JSON.parse(main_notification.rich_message) : main_notification.rich_message
          
          intro_block = rich_message.find { |block| block['type'] == 'context' }
          intro_text = intro_block.dig('elements', 0, 'text')
          # Observer should use casual name (not Slack mention) since they have no Slack identity
          expect(intro_text).to include(observer.casual_name)
          # Observer's mention should not be a Slack mention, but observed people may still have Slack mentions
          # Check that the observer's mention specifically is not a Slack mention
          expect(intro_text).to match(/as told by #{Regexp.escape(observer.casual_name)}/)
        end

        it 'falls back to favicon for icon_url' do
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids, company.id)

          main_notification = Notification.where(notification_type: 'observation_channel')
                                        .where("metadata->>'is_main_message' = 'true'")
                                        .first
          expect(main_notification.metadata['icon_url']).to include('/favicon-32x32.png')
        end
      end

      context 'when observed people have Slack identities' do
        before do
          observee_slack_identity = observee_teammate.teammate_identities.find_by(provider: 'slack')
          observee_slack_identity.update!(uid: 'U789012', name: 'Observed Slack Name')
        end

        it 'uses Slack handles for observed people in intro text' do
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids, company.id)

          main_notification = Notification.where(notification_type: 'observation_channel')
                                        .where("metadata->>'is_main_message' = 'true'")
                                        .first
          rich_message = main_notification.rich_message.is_a?(String) ? JSON.parse(main_notification.rich_message) : main_notification.rich_message
          
          intro_block = rich_message.find { |block| block['type'] == 'context' }
          intro_text = intro_block.dig('elements', 0, 'text')
          expect(intro_text).to include('<@U789012>')
        end
      end
    end

    context 'when observation story exceeds 2500 characters' do
      let(:notify_teammate_ids) { [observee_teammate.id.to_s] }
      let(:long_story) { 'A' * 3000 } # Story that exceeds 2500 chars
      let(:observation_with_long_story) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :observed_only, story: long_story)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs
      end

      it 'truncates story at 2500 characters and includes view more link' do
        job = Observations::PostNotificationJob.new
        job.perform(observation_with_long_story.id, notify_teammate_ids)

        main_notification = Notification.where(notification_type: 'observation_dm')
                                       .where("metadata->>'is_thread_reply' != 'true' OR metadata->>'is_thread_reply' IS NULL")
                                       .first
        expect(main_notification).to be_present
        
        rich_message = main_notification.rich_message.is_a?(String) ? JSON.parse(main_notification.rich_message) : main_notification.rich_message
        story_block = rich_message.find { |block| block['type'] == 'section' && block.dig('text', 'text') }
        story_text = story_block.dig('text', 'text')
        
        # Story should be truncated to 2500 chars plus the view more link
        expect(story_text.length).to be <= 3000
        expect(story_text.length).to be > 2500 # Should include the link text
        expect(story_text).to include('View the rest of this story')
        expect(story_text).to include('OurGruuv')
        # Should include a link to the observation
        permalink_url = observation_with_long_story.decorate.permalink_url
        expect(story_text).to include(permalink_url)
      end

      it 'does not raise invalid_blocks error when posting to Slack' do
        # Mock SlackService to verify it doesn't raise invalid_blocks error
        allow(slack_service).to receive(:post_message) do |notification_id|
          notification = Notification.find(notification_id)
          rich_message = notification.rich_message.is_a?(String) ? JSON.parse(notification.rich_message) : notification.rich_message
          
          # Verify all text fields are within Slack's 3000 char limit
          rich_message.each do |block|
            if block['text'] && block['text']['text']
              expect(block['text']['text'].length).to be <= 3000, "Block text exceeds 3000 chars: #{block['text']['text'].length}"
            end
            if block['elements']
              block['elements'].each do |element|
                if element['text']
                  expect(element['text'].length).to be <= 3000, "Element text exceeds 3000 chars: #{element['text'].length}"
                end
              end
            end
          end
          
          notification.update!(status: 'sent_successfully', message_id: '1234567890.123456')
          { success: true, message_id: '1234567890.123456' }
        end

        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation_with_long_story.id, notify_teammate_ids)
        }.not_to raise_error
      end
    end
  end
end
