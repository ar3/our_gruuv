class Observations::PostNotificationJob < ApplicationJob
  queue_as :default

  def perform(observation_id, notify_teammate_ids = [], kudos_channel_organization_id = nil)
    Rails.logger.info "🔍🔍🔍🔍🔍 PostNotificationJob: perform: observation_id: #{observation_id}, notify_teammate_ids: #{notify_teammate_ids}, kudos_channel_organization_id: #{kudos_channel_organization_id}"
    observation = Observation.find(observation_id)
    
    # Send DMs to selected teammates
    notify_teammate_ids.each do |teammate_id|
      teammate = Teammate.find(teammate_id)
      send_dm_to_teammate(observation, teammate)
    end
    
    # Post to kudos channel if requested
    if kudos_channel_organization_id.present?
      post_to_channel(observation, kudos_channel_organization_id)
    end
  end

  private

  def send_dm_to_teammate(observation, teammate)
    return unless teammate.slack_user_id.present?
    
    # Create notification record first
    notification = Notification.create!(
      notifiable_type: 'Observation',
      notifiable_id: observation.id,
      notification_type: 'observation_dm',
      status: 'preparing_to_send',
      metadata: { 'channel' => teammate.slack_user_id },
      fallback_text: build_dm_message(observation)[:fallback_text],
      rich_message: build_dm_message(observation)[:blocks].to_json
    )
    
    # Use existing SlackService
    begin
      SlackService.new(observation.company).post_message(notification.id)
    rescue => e
      # Log the error but don't re-raise it
      Rails.logger.error "Failed to send Slack notification: #{e.message}"
    end
  end

  def build_dm_message(observation)
    observer_name = observation.observer.preferred_name || observation.observer.first_name
    feelings_text = build_feelings_text(observation)
    privacy_text = build_privacy_text(observation)
    ratings_text = build_ratings_text(observation)
    
    fallback_text = "🎯 New Observation from #{observer_name}\n\n#{feelings_text}\n\n#{observation.story[0..200]}...\n\n#{privacy_text}\n#{ratings_text}"
    
    blocks = [
      {
        type: "header",
        text: {
          type: "plain_text",
          text: "🎯 New Observation from #{observer_name}"
        }
      },
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: feelings_text
        }
      },
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: observation.story
        }
      },
      {
        type: "context",
        elements: [
          {
            type: "mrkdwn",
            text: "#{privacy_text} | #{ratings_text}"
          }
        ]
      },
    ]
    
    # Add GIF URLs for unfurling in Slack
    if observation.story_extras.present? && observation.story_extras['gif_urls'].present?
      gif_urls = Array(observation.story_extras['gif_urls']).reject(&:blank?)
      gif_urls.each do |gif_url|
        blocks << {
          type: "section",
          text: {
            type: "mrkdwn",
            text: gif_url
          }
        }
      end
    end
    
    {
      fallback_text: fallback_text,
      blocks: blocks
    }
  end

  def build_feelings_text(observation)
    feelings = []
    feelings << observation.primary_feeling&.humanize if observation.primary_feeling.present?
    feelings << observation.secondary_feeling&.humanize if observation.secondary_feeling.present?
    
    if feelings.any?
      "Feeling: #{feelings.join(' + ')}"
    else
      ""
    end
  end

  def build_privacy_text(observation)
    case observation.privacy_level
    when 'observer_only'
      "Privacy: 🔒 Just for me (Journal)"
    when 'observed_only'
      "Privacy: 👤 Just for you"
    when 'managers_only'
      "Privacy: 👔 For your managers"
    when 'observed_and_managers'
      "Privacy: 👥 For you and your managers"
    when 'public_to_company'
      "Privacy: 🏢 Visible to company"
    when 'public_to_world'
      "Privacy: 🌍 Public to world"
    else
      "Privacy: #{observation.privacy_level.humanize}"
    end
  end

  def build_ratings_text(observation)
    positive_ratings = observation.observation_ratings.positive
    if positive_ratings.any?
      rating_texts = positive_ratings.map do |rating|
        "#{rating.rating.humanize} on #{rating.rateable.name}"
      end
      "Ratings: #{rating_texts.join(', ')}"
    else
      ""
    end
  end

  def post_to_channel(observation, organization_id)
    return unless observation.can_post_to_slack_channel? && observation.published?
    
    organization = Organization.find(organization_id)
    return unless organization.kudos_channel_id.present?
    
    channel = organization.kudos_channel
    channel_id = channel.third_party_id
    
    # Check if notification already exists (look for main message notifications)
    existing_notification = observation.notifications
                                        .where(notification_type: 'observation_channel')
                                        .where("metadata->>'is_main_message' = 'true'")
                                        .where("metadata->>'organization_id' = ?", organization_id.to_s)
                                        .successful
                                        .first
    
    if existing_notification
      # Update existing notification
      main_blocks = build_channel_main_message(observation, organization)
      thread_blocks = build_channel_thread_reply(observation, organization)
      
      # Get observer's casual name and Slack identity for username/icon override
      # Look in observation.company, not organization (kudos channel org)
      observer_teammate = observation.company.teammates.includes(:teammate_identities).find_by(person: observation.observer)
      observer_slack_identity = observer_teammate&.teammate_identities&.find { |ti| ti.provider == 'slack' }
      observer_casual_name = observation.observer.casual_name
      username_override = "#{observer_casual_name} via OG"
      
      # Get icon URL from observer's Slack profile image, fallback to favicon
      # Check that slack_identity exists and has a non-blank profile_image_url
      icon_url = if observer_slack_identity.present? && observer_slack_identity.profile_image_url.present?
        observer_slack_identity.profile_image_url
      else
        # Fallback to favicon - construct full URL
        "#{Rails.application.routes.url_helpers.root_url.chomp('/')}/favicon-32x32.png"
      end
      
      # Update main message
      main_notification = observation.notifications.create!(
        notification_type: 'observation_channel',
        original_message: existing_notification,
        status: 'preparing_to_send',
        metadata: { 
          channel: channel_id,
          organization_id: organization_id.to_s,
          is_main_message: true,
          username: username_override,
          icon_url: icon_url
        },
        rich_message: main_blocks,
        fallback_text: build_channel_fallback_text(observation, organization)
      )
      
      result = SlackService.new(observation.company).update_message(main_notification.id)
      
      # Update or create thread reply
      thread_notification = observation.notifications
                                        .where(notification_type: 'observation_channel')
                                        .where("metadata->>'is_thread_reply' = 'true'")
                                        .where(main_thread: existing_notification)
                                        .successful
                                        .first
      
      if thread_notification && existing_notification.message_id.present?
        thread_update = observation.notifications.create!(
          notification_type: 'observation_channel',
          original_message: thread_notification,
          main_thread: existing_notification,
          status: 'preparing_to_send',
          metadata: {
            channel: channel_id,
            organization_id: organization_id.to_s,
            is_thread_reply: true,
            username: username_override,
            icon_url: icon_url
          },
          rich_message: thread_blocks,
          fallback_text: build_thread_fallback_text(observation, organization)
        )
        SlackService.new(observation.company).update_message(thread_update.id)
      elsif existing_notification.message_id.present?
        # Create new thread reply
        thread_notification = observation.notifications.create!(
          notification_type: 'observation_channel',
          main_thread: existing_notification,
          status: 'preparing_to_send',
          metadata: {
            channel: channel_id,
            organization_id: organization_id.to_s,
            is_thread_reply: true,
            username: username_override,
            icon_url: icon_url
          },
          rich_message: thread_blocks,
          fallback_text: build_thread_fallback_text(observation, organization)
        )
        SlackService.new(observation.company).post_message(thread_notification.id)
      end
      
      result
    else
      # Create new notification
      main_blocks = build_channel_main_message(observation, organization)
      thread_blocks = build_channel_thread_reply(observation, organization)
      
      # Get observer's casual name and Slack identity for username/icon override
      # Look in observation.company, not organization (kudos channel org)
      observer_teammate = observation.company.teammates.includes(:teammate_identities).find_by(person: observation.observer)
      observer_slack_identity = observer_teammate&.teammate_identities&.find { |ti| ti.provider == 'slack' }
      observer_casual_name = observation.observer.casual_name
      username_override = "#{observer_casual_name} via OG"
      
      # Get icon URL from observer's Slack profile image, fallback to favicon
      # Check that slack_identity exists and has a non-blank profile_image_url
      icon_url = if observer_slack_identity.present? && observer_slack_identity.profile_image_url.present?
        observer_slack_identity.profile_image_url
      else
        # Fallback to favicon - construct full URL
        "#{Rails.application.routes.url_helpers.root_url.chomp('/')}/favicon-32x32.png"
      end
      
      main_notification = observation.notifications.create!(
        notification_type: 'observation_channel',
        status: 'preparing_to_send',
        metadata: {
          channel: channel_id,
          organization_id: organization_id.to_s,
          is_main_message: true,
          username: username_override,
          icon_url: icon_url
        },
        rich_message: main_blocks,
        fallback_text: build_channel_fallback_text(observation, organization)
      )
      
      result = SlackService.new(observation.company).post_message(main_notification.id)
      
      # Create thread reply if main message was successful
      if result[:success] && main_notification.reload.message_id.present?
        # Use same username and icon override for thread reply
        thread_notification = observation.notifications.create!(
          notification_type: 'observation_channel',
          main_thread: main_notification,
          status: 'preparing_to_send',
          metadata: {
            channel: channel_id,
            organization_id: organization_id.to_s,
            is_thread_reply: true,
            username: username_override,
            icon_url: icon_url
          },
          rich_message: thread_blocks,
          fallback_text: build_thread_fallback_text(observation, organization)
        )
        SlackService.new(observation.company).post_message(thread_notification.id)
      end
      
      result
    end
  rescue => e
    Rails.logger.error "Failed to post observation to channel: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    { success: false, error: e.message }
  end

  def build_channel_main_message(observation, organization)
    # Load observer teammate with slack identity from observation's company (not the kudos channel org)
    observer_teammate = observation.company.teammates.includes(:teammate_identities).find_by(person: observation.observer)
    
    # Get observer's Slack mention or fallback to casual name
    # Check slack_identity directly to ensure it's loaded
    observer_slack_identity = observer_teammate&.teammate_identities&.find { |ti| ti.provider == 'slack' }
    observer_slack_id = observer_slack_identity&.uid
    observer_mention = if observer_slack_id.present?
      "<@#{observer_slack_id}>"
    else
      observation.observer.casual_name
    end
    
    # Get observed Slack mentions or fallback to casual names
    # Observed teammates are already in observation.company (validation ensures this)
    # Ensure we load teammate_identities for observed teammates
    observed_mentions = observation.observed_teammates.includes(:teammate_identities).map do |teammate|
      # Check slack_identity directly to ensure it's loaded
      slack_identity = teammate.teammate_identities.find { |ti| ti.provider == 'slack' }
      slack_id = slack_identity&.uid
      if slack_id.present?
        "<@#{slack_id}>"
      else
        teammate.person.casual_name
      end
    end
    
    # Build intro text: "New awesome story about <slack mentions of observed> as told by <slack mention of observer>"
    intro_text = "New awesome story about #{observed_mentions.join(', ')} as told by #{observer_mention}"
    
    blocks = [
      {
        type: "context",
        elements: [
          {
            type: "mrkdwn",
            text: "_#{intro_text}_"
          }
        ]
      },
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: observation.story
        }
      }
    ]
    
    # Add GIF URLs as image blocks
    if observation.story_extras.present? && observation.story_extras['gif_urls'].present?
      gif_urls = Array(observation.story_extras['gif_urls']).reject(&:blank?)
      gif_urls.each do |gif_url|
        blocks << {
          type: "image",
          image_url: gif_url,
          alt_text: "GIF"
        }
      end
    end
    
    blocks
  end

  def build_channel_thread_reply(observation, organization)
    observer_casual_name = observation.observer.casual_name
    observer_public_url = Rails.application.routes.url_helpers.public_person_url(observation.observer)
    feelings_sentence = observation.feelings_display
    permalink_url = observation.decorate.permalink_url
    
    blocks = []
    
    # Add feelings sentence at top: "This story about <observed links> made <observer link> feel <feelings_sentence>"
    if feelings_sentence.present?
      # Build observed links
      observed_links = observation.observed_teammates.map do |teammate|
        person = teammate.person
        person_public_url = Rails.application.routes.url_helpers.public_person_url(person)
        person_casual_name = person.casual_name
        "<#{person_public_url}|#{person_casual_name}>"
      end
      
      # Build the sentence with links
      story_link = "<#{permalink_url}|This story>"
      observer_link = "<#{observer_public_url}|#{observer_casual_name}>"
      about_text = observed_links.any? ? " about #{observed_links.join(', ')}" : ""
      
      feelings_text = "#{story_link}#{about_text} made #{observer_link} feel #{feelings_sentence}"
      
      blocks << {
        type: "section",
        text: {
          type: "mrkdwn",
          text: feelings_text
        }
      }
    end
    
    # Add ratings using new formatter (grouped by type, then rating level)
    rating_sentences = observation.format_ratings_by_type_and_level(format: :slack)
    if rating_sentences.any?
      blocks << {
        type: "section",
        text: {
          type: "mrkdwn",
          text: rating_sentences.join("\n")
        }
      }
    end
    
    # Add ending message with company name and new observation link (in subtle context block)
    # Get the observer's company (the company where the observer has a teammate)
    observer_company = observation.company
    company_name = observer_company.name
    new_observation_url = Rails.application.routes.url_helpers.new_organization_observation_url(observer_company)
    
    ending_text = "Adding stories like this to the *#{company_name}* novel will help shape us, because they are specific about the best examples of us executing assignments, demonstrating abilities, and exemplifying the aspirations/values we focus on.\n\nThis one was great, who's next to add to <#{new_observation_url}|OUR Story>?"
    
    blocks << {
      type: "context",
      elements: [
        {
          type: "mrkdwn",
          text: ending_text
        }
      ]
    }
    
    blocks
  end

  def build_channel_fallback_text(observation, organization)
    observer_name = observation.observer.preferred_name || observation.observer.first_name
    observed_names = observation.observed_teammates.map { |t| t.person.preferred_name || t.person.first_name }.join(', ')
    "🎉 New Public Observation from #{observer_name}#{observed_names.present? ? " about #{observed_names}" : ""}"
  end

  def build_thread_fallback_text(observation, organization)
    "View details and share your thoughts!"
  end
end