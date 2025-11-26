# frozen_string_literal: true

module Debug
  # Service to gather Slack notification debug information for observations
  class ObservationSlackDebugService
    attr_reader :observation, :organization

    def initialize(observation:, organization:)
      @observation = observation
      @organization = organization
    end

    def call
      {
        observer: observer_data,
        observed: observed_data,
        slack_metadata: slack_metadata,
        slack_mentions: slack_mentions
      }
    end

    private

    def observer_data
      # Look in observation.company, not organization (kudos channel org)
      observer_teammate = observation.company.teammates.includes(:teammate_identities).find_by(person: observation.observer)
      observer_slack_identity = observer_teammate&.teammate_identities&.find { |ti| ti.provider == 'slack' }
      
      {
        casual_name: observation.observer.casual_name,
        slack_identity: slack_identity_data(observer_slack_identity),
        teammate: observer_teammate
      }
    end

    def observed_data
      observation.observed_teammates.includes(:teammate_identities).map do |teammate|
        slack_identity = teammate.teammate_identities.find { |ti| ti.provider == 'slack' }
        
        {
          casual_name: teammate.person.casual_name,
          slack_identity: slack_identity_data(slack_identity),
          teammate: teammate
        }
      end
    end

    def slack_identity_data(slack_identity)
      return nil unless slack_identity

      {
        uid: slack_identity.uid,
        name: slack_identity.name,
        profile_image_url: slack_identity.profile_image_url,
        present: true
      }
    end

    def slack_metadata
      # Look in observation.company, not organization (kudos channel org)
      observer_teammate = observation.company.teammates.includes(:teammate_identities).find_by(person: observation.observer)
      observer_slack_identity = observer_teammate&.teammate_identities&.find { |ti| ti.provider == 'slack' }
      observer_casual_name = observation.observer.casual_name
      username_override = "#{observer_casual_name} via OG"
      
      # Check that slack_identity exists and has a non-blank profile_image_url
      icon_url = if observer_slack_identity.present? && observer_slack_identity.profile_image_url.present?
        observer_slack_identity.profile_image_url
      else
        "#{Rails.application.routes.url_helpers.root_url.chomp('/')}/favicon-32x32.png"
      end

      {
        username_override: username_override,
        icon_url: icon_url,
        using_slack_image: observer_slack_identity.present? && observer_slack_identity.profile_image_url.present?,
        fallback_to_favicon: observer_slack_identity.blank? || observer_slack_identity.profile_image_url.blank?
      }
    end

    def slack_mentions
      # Look in observation.company, not organization (kudos channel org)
      observer_teammate = observation.company.teammates.includes(:teammate_identities).find_by(person: observation.observer)
      observer_slack_identity = observer_teammate&.teammate_identities&.find { |ti| ti.provider == 'slack' }
      observer_slack_id = observer_slack_identity&.uid
      
      observer_mention = if observer_slack_id.present?
        "<@#{observer_slack_id}>"
      else
        observation.observer.casual_name
      end

      observed_mentions = observation.observed_teammates.includes(:teammate_identities).map do |teammate|
        slack_identity = teammate.teammate_identities.find { |ti| ti.provider == 'slack' }
        slack_id = slack_identity&.uid
        
        if slack_id.present?
          "<@#{slack_id}>"
        else
          teammate.person.casual_name
        end
      end

      {
        observer: observer_mention,
        observed: observed_mentions,
        observer_slack_id: observer_slack_id
      }
    end
  end
end

