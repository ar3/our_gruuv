class Observations::PostNotificationJob < ApplicationJob
  queue_as :default

  def perform(observation_id, notify_teammate_ids = [], kudos_channel_organization_id = nil)
    Rails.logger.info "🔍🔍🔍🔍🔍 PostNotificationJob: perform: observation_id: #{observation_id}, notify_teammate_ids: #{notify_teammate_ids}, kudos_channel_organization_id: #{kudos_channel_organization_id}"
    observation = Observation.find(observation_id)
    
    # Send group DM to selected teammates
    if notify_teammate_ids.present?
      send_group_dm(observation, notify_teammate_ids)
    end
    
    # Post to kudos channel if requested
    if kudos_channel_organization_id.present?
      post_to_channel(observation, kudos_channel_organization_id)
    end
  end

  private

  def send_group_dm(observation, teammate_ids)
    # Get all teammates with Slack identities from the provided list
    teammates = Teammate.where(id: teammate_ids).select { |t| t.slack_user_id.present? }
    
    # Always include the observer if they have Slack configured
    observer_teammate = observation.company.teammates.find_by(person: observation.observer)
    if observer_teammate&.slack_user_id.present?
      # Add observer to the list if not already included
      unless teammates.any? { |t| t.id == observer_teammate.id }
        teammates << observer_teammate
        teammate_ids = teammate_ids + [observer_teammate.id]
      end
    end
    
    # If no teammates with Slack (including observer), return early
    return if teammates.empty?
    
    slack_user_ids = teammates.map(&:slack_user_id).compact
    
    # If only one teammate (could be just observer or just one selected), send regular DM
    if slack_user_ids.length == 1
      send_dm_to_teammate(observation, teammates.first)
      return
    end
    
    # For multiple teammates, create group DM
    slack_service = SlackService.new(observation.company)
    
    # Open or create group DM
    group_dm_result = slack_service.open_or_create_group_dm(user_ids: slack_user_ids)
    
    unless group_dm_result[:success]
      Rails.logger.error "Failed to open group DM: #{group_dm_result[:error]}"
      # Fallback to individual DMs if group DM fails
      teammates.each do |teammate|
        send_dm_to_teammate(observation, teammate)
      end
      return
    end
    
    group_channel_id = group_dm_result[:channel_id]
    
    # Use same template as public channel posts (main message + thread reply)
    post_to_dm_channel(observation, group_channel_id, teammate_ids, is_group_dm: true)
  end

  def send_dm_to_teammate(observation, teammate)
    return unless teammate.slack_user_id.present?
    
    # Use same template as public channel posts (main message + thread reply)
    post_to_dm_channel(observation, teammate.slack_user_id, [teammate.id], is_group_dm: false)
  end

  def post_to_dm_channel(observation, channel_id, teammate_ids, is_group_dm: false)
    # Build main message and thread reply using same template as channel posts
    # Use observation.company as the organization for building messages
    main_blocks = build_channel_main_message(observation, observation.company)
    thread_blocks = build_channel_thread_reply(observation, observation.company)
    
    # Get observer's casual name and Slack identity for username/icon override
    observer_teammate = observation.company.teammates.includes(:teammate_identities).find_by(person: observation.observer)
    observer_slack_identity = observer_teammate&.teammate_identities&.find { |ti| ti.provider == 'slack' }
    observer_casual_name = observation.observer.casual_name
    username_override = "#{observer_casual_name} via OG"
    
    # Get icon URL from observer's Slack profile image, fallback to favicon
    icon_url = if observer_slack_identity.present? && observer_slack_identity.profile_image_url.present?
      observer_slack_identity.profile_image_url
    else
      "#{Rails.application.routes.url_helpers.root_url.chomp('/')}/favicon-32x32.png"
    end
    
    # Create main message notification
    main_notification = observation.notifications.create!(
      notification_type: 'observation_dm',
      status: 'preparing_to_send',
      metadata: {
        channel: channel_id,
        is_group_dm: is_group_dm,
        teammate_ids: teammate_ids,
        username: username_override,
        icon_url: icon_url
      },
      rich_message: main_blocks,
      fallback_text: build_channel_fallback_text(observation, observation.company)
    )
    
    result = SlackService.new(observation.company).post_message(main_notification.id)
    
    # Create thread reply if main message was successful
    if result[:success] && main_notification.reload.message_id.present?
      thread_notification = observation.notifications.create!(
        notification_type: 'observation_dm',
        main_thread: main_notification,
        status: 'preparing_to_send',
        metadata: {
          channel: channel_id,
          is_group_dm: is_group_dm,
          teammate_ids: teammate_ids,
          is_thread_reply: true,
          username: username_override,
          icon_url: icon_url
        },
        rich_message: thread_blocks,
        fallback_text: build_thread_fallback_text(observation, observation.company)
      )
      SlackService.new(observation.company).post_message(thread_notification.id)
    end
    
    result
  rescue => e
    Rails.logger.error "Failed to post observation to DM: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    { success: false, error: e.message }
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
    
    ending_text = "Adding stories like this to the *#{company_name}* novel will help shape us, because they are specific about the best examples of us executing assignments, demonstrating abilities, and exemplifying the aspirational values we focus on.\n\nThis one was great, who's next to add to <#{new_observation_url}|OUR Story>?"
    
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