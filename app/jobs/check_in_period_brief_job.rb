# frozen_string_literal: true

class CheckInPeriodBriefJob < ApplicationJob
  queue_as :default

  def perform(check_in_class_name, check_in_id, og_consultation_id)
    check_in = check_in_class_name.constantize.find_by(id: check_in_id)
    consultation = OgConsultation.find_by(id: og_consultation_id)
    return if check_in.nil? || consultation.nil?

    consultation.mark_processing!
    viewer_person = consultation.triggered_by_teammate&.person
    return fail_missing_viewer(consultation) if viewer_person.nil?

    runner = OgConsultations::Kinds.runner_class_for(consultation.kind)
    runner.call(check_in: check_in, og_consultation: consultation, viewer_person: viewer_person)
  end

  private

  def fail_missing_viewer(consultation)
    consultation.update!(
      status: "failed",
      error_message: "Missing viewer for period brief consultation.",
      completed_at: Time.current
    )
  end
end
