# frozen_string_literal: true

module OgConsultations
  # Creates an append-only billable consultation + OgoSearchResult for transcript/Slack extraction runs.
  class StartOgoSearch
    def self.call(
      subject:,
      kind:,
      organization_id:,
      triggered_by_teammate_id: nil,
      units_total:,
      extraction_version:,
      model_id:,
      prompt_version:
    )
      new(
        subject: subject,
        kind: kind,
        organization_id: organization_id,
        triggered_by_teammate_id: triggered_by_teammate_id,
        units_total: units_total,
        extraction_version: extraction_version,
        model_id: model_id,
        prompt_version: prompt_version
      ).call
    end

    def initialize(
      subject:,
      kind:,
      organization_id:,
      triggered_by_teammate_id:,
      units_total:,
      extraction_version:,
      model_id:,
      prompt_version:
    )
      @subject = subject
      @kind = kind
      @organization_id = organization_id
      @triggered_by_teammate_id = triggered_by_teammate_id
      @units_total = units_total
      @extraction_version = extraction_version
      @model_id = model_id
      @prompt_version = prompt_version
    end

    def call
      consultation = OgConsultation.create!(
        kind: @kind,
        subject: @subject,
        organization_id: @organization_id,
        triggered_by_teammate_id: @triggered_by_teammate_id,
        status: 'pending',
        billable: OgConsultations::Kinds.fetch(@kind).billable,
        units_total: @units_total,
        units_completed: 0,
        model_id: @model_id,
        prompt_version: @prompt_version
      )
      result = OgConsultations::Kinds.result_class_for(@kind).create!(
        og_consultation: consultation,
        items_count: 0,
        extraction_version: @extraction_version
      )
      consultation.update!(result: result)
      consultation.mark_processing!
      consultation
    end
  end
end
