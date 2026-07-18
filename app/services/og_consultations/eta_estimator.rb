# frozen_string_literal: true

module OgConsultations
  # Estimates total expected wall time for a consultation from recent unit/run durations.
  # Clients show remaining as max(0, estimated_duration_seconds - elapsed_seconds).
  class EtaEstimator
    Result = Data.define(
      :estimated_duration_seconds,
      :eta_confidence,
      :units_total,
      :units_completed,
      :sample_size
    )

    SAMPLE_SIZE = 20
    MIN_SAMPLES = 3
    CACHE_TTL = 45.seconds

    def self.call(consultation)
      new(consultation).call
    end

    def initialize(consultation)
      @consultation = consultation
    end

    def call
      units_total = @consultation.units_total.to_i
      units_completed = @consultation.units_completed.to_i

      cache_key = [
        'og_eta_v2',
        @consultation.kind,
        @consultation.model_id,
        @consultation.prompt_version,
        units_total
      ]

      median_ms, sample_size, basis = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        median_duration_ms
      end

      confidence = confidence_for(sample_size)
      estimated =
        if median_ms.present? && confidence != 'low'
          if basis == :unit && units_total.positive?
            ((units_total * median_ms) / 1000.0).ceil
          elsif basis == :consultation
            (median_ms / 1000.0).ceil
          end
        end

      Result.new(
        estimated_duration_seconds: estimated,
        eta_confidence: confidence,
        units_total: units_total,
        units_completed: units_completed,
        sample_size: sample_size
      )
    end

    private

    def median_duration_ms
      invocation_durations = invocation_durations_ms
      if invocation_durations.size >= MIN_SAMPLES
        return [median(invocation_durations), invocation_durations.size, :unit]
      end

      wall_durations = consultation_wall_durations_ms
      if wall_durations.size >= MIN_SAMPLES
        return [median(wall_durations), wall_durations.size, :consultation]
      end

      if invocation_durations.size >= wall_durations.size
        [nil, invocation_durations.size, :unit]
      else
        [nil, wall_durations.size, :consultation]
      end
    end

    def invocation_durations_ms
      purpose = OgConsultations::Kinds.fetch(@consultation.kind).llm_purpose
      scope = LlmInvocation.completed.where(purpose: purpose).where.not(duration_ms: nil)
      scope = scope.where(model_id: @consultation.model_id) if @consultation.model_id.present?
      if @consultation.prompt_version.present?
        scope = scope.where(prompt_version: @consultation.prompt_version)
      end
      scope.order(finished_at: :desc).limit(SAMPLE_SIZE).pluck(:duration_ms).compact
    end

    def consultation_wall_durations_ms
      OgConsultation
        .completed
        .where(kind: @consultation.kind)
        .where.not(started_at: nil, completed_at: nil)
        .order(completed_at: :desc)
        .limit(SAMPLE_SIZE)
        .pluck(:started_at, :completed_at)
        .filter_map do |started_at, completed_at|
          next if started_at.blank? || completed_at.blank?

          ((completed_at - started_at) * 1000).round
        end
        .select(&:positive?)
    end

    def median(values)
      sorted = values.map(&:to_i).sort
      mid = sorted.length / 2
      if sorted.length.odd?
        sorted[mid]
      else
        ((sorted[mid - 1] + sorted[mid]) / 2.0).round
      end
    end

    def confidence_for(sample_size)
      return 'low' if sample_size < MIN_SAMPLES
      return 'medium' if sample_size < 10

      'high'
    end
  end
end
