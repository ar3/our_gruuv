# frozen_string_literal: true

# Awards one calibration item: creates a MilestoneAward (co-sign or skip) for levels
# 1..official. Official 0 creates no milestones; ability stays "new".
class AbilityMilestoneCalibrationAwardService
  CERTIFICATION_NOTE = 'Initial ability milestone calibration'

  def self.call(...) = new(...).call

  def initialize(
    item:,
    official_level:,
    certifying_teammate:,
    created_by_person:,
    organization:,
    certification_note: nil,
    awarder_typed_name: nil,
    skip_cosign: nil,
    cosign_invitee_ids: []
  )
    @item = item
    @official_level = official_level.to_i
    @certifying_teammate = certifying_teammate
    @created_by_person = created_by_person
    @organization = organization
    @teammate = item.ability_milestone_calibration.teammate
    @certification_note = certification_note.to_s.strip.presence || CERTIFICATION_NOTE
    @awarder_typed_name = awarder_typed_name
    @skip_cosign = skip_cosign
    @cosign_invitee_ids = cosign_invitee_ids
  end

  def call
    unless (0..5).cover?(@official_level)
      return Result.err('Official Milestone must be between 0 and 5.')
    end

    if @item.awarded?
      return Result.err('This ability already has a milestone earned in this calibration pass.')
    end

    unless @item.ready_for_review?
      return Result.err('Both employee and manager must rate this ability before recognizing and certifying.')
    end

    ApplicationRecord.transaction do
      if @official_level.positive?
        award_result = create_milestone_award!
        return award_result unless award_result.ok?
      end

      @item.update!(
        official_milestone_level: @official_level,
        awarded_at: Time.current,
        awarded_by_teammate: @certifying_teammate
      )

      Result.ok(@item.reload)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages.join(', '))
  rescue StandardError => e
    Result.err("Could not recognize and certify: #{e.message}")
  end

  private

  def create_milestone_award!
    company = @organization.root_company || @organization
    ability = Ability.find_by(id: @item.ability_id, company: company)
    return Result.err('Ability not found.') unless ability

    if @awarder_typed_name.blank?
      return Result.err('Type your full name to certify this milestone.')
    end

    if @skip_cosign.nil? && Array(@cosign_invitee_ids).empty?
      return Result.err('Invite at least one co-signer, or skip co-sign.')
    end

    MilestoneAwards::CreateService.call(
      teammate: @teammate,
      ability: ability,
      official_level: @official_level,
      certifying_teammate: @certifying_teammate,
      created_by_person: @created_by_person,
      organization: @organization,
      source: :calibration,
      awarder_typed_name: @awarder_typed_name,
      skip_cosign: @skip_cosign,
      cosign_invitee_ids: @cosign_invitee_ids,
      certification_note: @certification_note,
      privacy_level: 'company',
      calibration_item: @item
    )
  end
end
