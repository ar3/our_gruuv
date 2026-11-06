# frozen_string_literal: true

module Observations
  # One click for a transcript-sourced draft: publish, set who can see it, and either
  # stay quiet or post it in the company channel.
  class ConfirmTranscriptDraft
    def self.call(observation:, intent:)
      new(observation, intent).call
    end

    def initialize(observation, intent)
      @observation = observation
      @intent = intent.to_s
    end

    def call
      return Result.err("Only an unpublished transcript draft can be confirmed this way.") unless confirmable?

      case @intent
      when "quiet"
        publish_quietly
      when "channel"
        publish_to_channel
      else
        Result.err("Choose whether to stay quiet or post in the company channel.")
      end
    end

    private

    def confirmable?
      @observation.draft? && @observation.ogo_consult_sourced?
    end

    def publish_quietly
      @observation.update!(privacy_level: :observed_and_managers)
      Observations::PublishService.call(@observation)
      Result.ok("Published. Nobody was notified.")
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.to_sentence)
    end

    def publish_to_channel
      if @observation.has_negative_ratings?
        return Result.err("A concerning rating stays with the people who should see it, so this cannot go in the company channel.")
      end

      channel = @observation.company&.kudos_channel
      return Result.err("No company channel is set up yet.") if channel.blank?

      @observation.update!(privacy_level: :public_to_company)
      privacy_changed = Observations::PublishService.call(@observation)
      if privacy_changed
        return Result.err("Published for the people who should see it. A concerning rating kept it out of the company channel.")
      end

      Observations::PostNotificationJob.perform_and_get_result(@observation.id, [], @observation.company_id)
      Result.ok("Published to #{@observation.company.name} and posted in #{channel.display_name}.")
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.to_sentence)
    end

  end
end
