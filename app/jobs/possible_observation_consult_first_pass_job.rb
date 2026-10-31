# frozen_string_literal: true

class PossibleObservationConsultFirstPassJob < ApplicationJob
  queue_as :default

  def perform(possible_observation_consult_id)
    consult = PossibleObservationConsult.find_by(id: possible_observation_consult_id)
    return if consult.nil?

    consult.update!(first_pass_status: "processing", first_pass_error: nil)
    cues = Transcripts::MomentCuesService.call(raw: consult.source_raw)

    if cues.empty?
      # No timed cues — seed empty maps and complete so UI can fall back to checkboxes.
      consult.update!(
        speaker_map: { "version" => 1, "labels" => {} },
        cue_annotations: { "version" => 1, "cues" => {} },
        first_pass_status: "completed",
        first_pass_error: nil
      )
      return
    end

    org_ids = consult.organization.self_and_descendants.map(&:id)
    teammates = CompanyTeammate.employed.where(organization_id: org_ids).includes(:person).to_a

    llm_by_cue_id = Llm::TranscriptCueFirstPass.call(
      cues: cues,
      organization_id: consult.organization_id,
      teammates: teammates,
      triggered_by_teammate_id: consult.creator_company_teammate_id
    )

    PossibleObservationConsults::ApplyFirstPassResults.call(
      consult: consult,
      cues: cues,
      llm_by_cue_id: llm_by_cue_id
    )
  rescue StandardError => e
    consult&.update!(
      first_pass_status: "failed",
      first_pass_error: e.message.to_s.truncate(10_000)
    )
    Rails.logger.error(
      "PossibleObservationConsultFirstPassJob #{possible_observation_consult_id}: #{e.class} #{e.message}"
    )
  end
end
