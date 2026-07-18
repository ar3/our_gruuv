# frozen_string_literal: true

module OgConsultationSpecHelpers
  CONSULTATION_ATTRS = %i[
    triggered_by_teammate triggered_by_teammate_id completed_at started_at
    model_id error_message billable prompt_version units_total units_completed
  ].freeze

  def create_ability_clarity_consultation!(ability:, status: 'pending', output_text: nil, clarity_rating: nil, **attrs)
    consultation = OgConsultation.create!(
      {
        kind: OgConsultation::KIND_ABILITY_CLARITY,
        subject: ability,
        organization_id: ability.company_id,
        status: status,
        billable: true,
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
        units_total: 1,
        units_completed: status == 'completed' ? 1 : 0
      }.merge(attrs.slice(*CONSULTATION_ATTRS))
    )
    result = AbilityClarityResult.create!(
      og_consultation: consultation,
      output_text: output_text,
      clarity_rating: clarity_rating
    )
    consultation.update!(result: result)
    consultation
  end

  def create_assignment_clarity_consultation!(
    assignment:,
    status: 'pending',
    consult_focus: nil,
    clarity_recommendations: [],
    output_text: nil,
    clarity_rating: nil,
    clarity_score: nil,
    **attrs
  )
    consultation = OgConsultation.create!(
      {
        kind: OgConsultation::KIND_ASSIGNMENT_CLARITY,
        subject: assignment,
        organization_id: assignment.company_id,
        status: status,
        billable: true,
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
        units_total: 1,
        units_completed: status == 'completed' ? 1 : 0
      }.merge(attrs.slice(*CONSULTATION_ATTRS))
    )
    result = AssignmentClarityResult.create!(
      og_consultation: consultation,
      consult_focus: consult_focus,
      clarity_recommendations: clarity_recommendations,
      output_text: output_text,
      clarity_rating: clarity_rating,
      clarity_score: clarity_score
    )
    consultation.update!(result: result)
    consultation
  end

  def create_position_clarity_consultation!(position:, status: 'pending', **attrs)
    org_id = position.company&.id || position.title.company_id
    consultation = OgConsultation.create!(
      {
        kind: OgConsultation::KIND_POSITION_CLARITY,
        subject: position,
        organization_id: org_id,
        status: status,
        billable: true,
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
        units_total: 1,
        units_completed: status == 'completed' ? 1 : 0
      }.merge(attrs.slice(*CONSULTATION_ATTRS))
    )
    result = PositionClarityResult.create!(og_consultation: consultation)
    consultation.update!(result: result)
    consultation
  end

  def create_teammate_growth_consultation!(teammate:, organization:, status: 'pending', **attrs)
    consultation = OgConsultation.create!(
      {
        kind: OgConsultation::KIND_TEAMMATE_GROWTH,
        subject: teammate,
        organization_id: organization.id,
        status: status,
        billable: true,
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
        units_total: 1,
        units_completed: status == 'completed' ? 1 : 0
      }.merge(attrs.slice(*CONSULTATION_ATTRS))
    )
    result = TeammateGrowthResult.create!(og_consultation: consultation)
    consultation.update!(result: result)
    consultation
  end

  def create_ogo_search_consultation!(
    subject:,
    kind:,
    organization:,
    status: 'pending',
    items_count: 0,
    units_total: 1,
    **attrs
  )
    consultation = OgConsultation.create!(
      {
        kind: kind,
        subject: subject,
        organization_id: organization.id,
        status: status,
        billable: true,
        units_total: units_total,
        units_completed: status == 'completed' ? units_total : 0
      }.merge(attrs.slice(*CONSULTATION_ATTRS))
    )
    result = OgoSearchResult.create!(og_consultation: consultation, items_count: items_count)
    consultation.update!(result: result)
    consultation
  end
end

RSpec.configure do |config|
  config.include OgConsultationSpecHelpers
end
