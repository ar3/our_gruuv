class Observations::PostNotificationJob < ApplicationJob
  queue_as :default

  def perform(observation_id, notify_teammate_ids = [], kudos_channel_organization_id = nil)
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
    when 'public_observation'
      "Privacy: 🌍 Public to organization"
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
    return unless observation.privacy_level == 'public_observation' && observation.published?
    
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
      
      # Update main message
      main_notification = observation.notifications.create!(
        notification_type: 'observation_channel',
        original_message: existing_notification,
        status: 'preparing_to_send',
        metadata: { 
          channel: channel_id,
          organization_id: organization_id.to_s,
          is_main_message: true
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
            is_thread_reply: true
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
            is_thread_reply: true
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
      
      main_notification = observation.notifications.create!(
        notification_type: 'observation_channel',
        status: 'preparing_to_send',
        metadata: {
          channel: channel_id,
          organization_id: organization_id.to_s,
          is_main_message: true
        },
        rich_message: main_blocks,
        fallback_text: build_channel_fallback_text(observation, organization)
      )
      
      result = SlackService.new(observation.company).post_message(main_notification.id)
      
      # Create thread reply if main message was successful
      if result[:success] && main_notification.reload.message_id.present?
        thread_notification = observation.notifications.create!(
          notification_type: 'observation_channel',
          main_thread: main_notification,
          status: 'preparing_to_send',
          metadata: {
            channel: channel_id,
            organization_id: organization_id.to_s,
            is_thread_reply: true
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
    observer_name = observation.observer.preferred_name || observation.observer.first_name
    observer_teammate = organization.teammates.find_by(person: observation.observer)
    observer_slack_id = observer_teammate&.slack_user_id
    
    observed_names = observation.observed_teammates.map do |teammate|
      name = teammate.person.preferred_name || teammate.person.first_name
      slack_id = teammate.slack_user_id
      if slack_id
        "<@#{slack_id}>"
      else
        name
      end
    end
    
    observer_mention = observer_slack_id ? "<@#{observer_slack_id}>" : observer_name
    
    blocks = [
      {
        type: "header",
        text: {
          type: "plain_text",
          text: "🎉 New Public Observation!",
          emoji: true
        }
      },
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*Observer:* #{observer_mention}"
        }
      }
    ]
    
    if observed_names.any?
      blocks << {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*Observed:* #{observed_names.join(', ')}"
        }
      }
    end
    
    blocks << {
      type: "section",
      text: {
        type: "mrkdwn",
        text: observation.story
      }
    }
    
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
    
    blocks
  end

  def build_channel_thread_reply(observation, organization)
    permalink_url = observation.decorate.permalink_url
    feelings_text = build_feelings_text(observation)
    
    blocks = []
    
    if feelings_text.present?
      blocks << {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*Feelings:* #{feelings_text}"
        }
      }
    end
    
    # Add ratings with public page links
    positive_ratings = observation.observation_ratings.positive
    if positive_ratings.any?
      ratings_sections = []
      
      abilities = observation.abilities
      assignments = observation.assignments
      aspirations = observation.aspirations
      
      if abilities.any?
        ability_links = abilities.map do |ability|
          url = Rails.application.routes.url_helpers.organization_public_maap_ability_url(ability.organization, ability)
          "<#{url}|#{ability.name}>"
        end
        ratings_sections << "*Abilities:* #{ability_links.join(', ')}"
      end
      
      if assignments.any?
        assignment_links = assignments.map do |assignment|
          url = Rails.application.routes.url_helpers.organization_public_maap_assignment_url(assignment.company, assignment)
          "<#{url}|#{assignment.title}>"
        end
        ratings_sections << "*Assignments:* #{assignment_links.join(', ')}"
      end
      
      if aspirations.any?
        aspiration_links = aspirations.map do |aspiration|
          url = Rails.application.routes.url_helpers.organization_public_maap_aspiration_url(aspiration.organization, aspiration)
          "<#{url}|#{aspiration.name}>"
        end
        ratings_sections << "*Aspirations:* #{aspiration_links.join(', ')}"
      end
      
      if ratings_sections.any?
        blocks << {
          type: "section",
          text: {
            type: "mrkdwn",
            text: ratings_sections.join("\n")
          }
        }
      end
    end
    
    # Add observed's public pages
    if observation.observed_teammates.any?
      observed_links = observation.observed_teammates.map do |teammate|
        person = teammate.person
        url = Rails.application.routes.url_helpers.public_person_url(person)
        name = person.preferred_name || person.first_name
        "<#{url}|#{name}>"
      end
      
      blocks << {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*Observed People:* #{observed_links.join(', ')}"
        }
      }
    end
    
    # Add engagement message and permalink
    blocks << {
      type: "section",
      text: {
        type: "mrkdwn",
        text: "💬 Share your thoughts and reactions! <#{permalink_url}|View the full observation>"
      }
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