# frozen_string_literal: true

module Observations
  class StartOgoQualityConsult
    Result = Data.define(:ok, :observation, :consultation, :error) do
      def ok?
        ok
      end
    end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(organization:, current_person:, triggered_by_teammate:, observation: nil, story:, observee_ids:, observation_type:, privacy_level:, primary_feeling: nil, secondary_feeling: nil)
      @organization = organization
      @current_person = current_person
      @triggered_by_teammate = triggered_by_teammate
      @observation = observation
      @story = story.to_s
      @observee_ids = Array(observee_ids).reject(&:blank?)
      @observation_type = observation_type.to_s.presence || "generic"
      @privacy_level = privacy_level.to_s.presence
      @primary_feeling = primary_feeling
      @secondary_feeling = secondary_feeling
    end

    def call
      return fail_result("Add at least one observee and some story before consulting OG.") if @story.strip.blank?

      persist_observation!
      return fail_result("Add at least one observee and some story before consulting OG.") if observees_missing?

      inflight = @observation.latest_ogo_quality_consultation
      if inflight&.in_flight?
        return Result.new(ok: true, observation: @observation, consultation: inflight, error: nil)
      end

      entry = OgConsultations::Kinds.fetch(OgConsultation::KIND_OGO_QUALITY)
      consultation = OgConsultation.create!(
        kind: entry.kind,
        subject: @observation,
        organization_id: @observation.company_id,
        triggered_by_teammate: @triggered_by_teammate,
        status: "pending",
        billable: entry.billable,
        prompt_version: Ogo::Prompts::PROMPT_VERSION,
        units_total: 1,
        units_completed: 0
      )
      result = OgoQualityResult.create!(og_consultation: consultation, payload: {})
      consultation.update!(result: result)
      OgoQualityJob.perform_later(@observation.id, consultation.id)

      Result.new(ok: true, observation: @observation, consultation: consultation, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      fail_result(e.record.errors.full_messages.to_sentence.presence || e.message)
    end

    private

    def persist_observation!
      if @observation.nil? || @observation.new_record?
        type = Observation.observation_types.key?(@observation_type) ? @observation_type : "generic"
        privacy = @privacy_level.presence || default_privacy_for(type)
        @observation = @organization.observations.build(
          observer: @current_person,
          observation_type: type,
          created_as_type: type,
          privacy_level: privacy,
          story: @story,
          observed_at: Time.current,
          primary_feeling: @primary_feeling.presence,
          secondary_feeling: @secondary_feeling.presence
        )
        @observation.save!
        @observee_ids.each do |teammate_id|
          AddObserveeService.new(observation: @observation, teammate_id: teammate_id).call
        end
      else
        attrs = { story: @story }
        attrs[:primary_feeling] = @primary_feeling if @primary_feeling.present? || @primary_feeling == ""
        attrs[:secondary_feeling] = @secondary_feeling.presence
        @observation.update!(attrs.compact)
        if @observation.observees.none? && @observee_ids.any?
          @observee_ids.each do |teammate_id|
            AddObserveeService.new(observation: @observation, teammate_id: teammate_id).call
          end
        end
      end
      @observation.reload
    end

    def observees_missing?
      @observation.observees.none?
    end

    def default_privacy_for(type)
      case type
      when "feedback" then "observed_only"
      else "observed_and_managers"
      end
    end

    def fail_result(message)
      Result.new(ok: false, observation: @observation, consultation: nil, error: message)
    end
  end
end
