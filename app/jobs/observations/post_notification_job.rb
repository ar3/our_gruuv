class Observations::PostNotificationJob < ApplicationJob
  queue_as :default

  def perform(observation_id, notify_teammate_ids = [])
    observation = Observation.find(observation_id)
    
    # Send DMs to selected teammates
    notify_teammate_ids.each do |teammate_id|
      teammate = Teammate.find(teammate_id)
      send_dm_to_teammate(observation, teammate)
    end
    
    # TODO: Add channel posting logic here
  end

  private

  def send_dm_to_teammate(observation, teammate)
    return unless teammate.person.slack_user_id.present?
    
    message = build_dm_message(observation)
    
    # Use existing SlackService
    SlackService.post_message(
      channel: teammate.person.slack_user_id,
      text: message[:fallback_text],
      blocks: message[:blocks],
      notifiable_type: 'Observation',
      notifiable_id: observation.id,
      notification_type: 'observation_dm'
    )
  end

  def build_dm_message(observation)
    observer_name = observation.observer.preferred_name || observation.observer.first_name
    feelings_text = build_feelings_text(observation)
    privacy_text = build_privacy_text(observation)
    ratings_text = build_ratings_text(observation)
    
    fallback_text = "🎯 New Observation from #{observer_name}\n\n#{feelings_text}\n\n#{observation.story[0..200]}...\n\n#{privacy_text}\n#{ratings_text}\n\nView Kudos: #{observation.permalink_url}"
    
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
      {
        type: "actions",
        elements: [
          {
            type: "button",
            text: {
              type: "plain_text",
              text: "View Kudos"
            },
            url: observation.permalink_url
          }
        ]
      }
    ]
    
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
end