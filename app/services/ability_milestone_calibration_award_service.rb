# frozen_string_literal: true

# Awards one calibration item: creates TeammateMilestone rows for levels 1..official
# (same fill pattern as bulk award). Official 0 creates no milestones; ability stays "new".
class AbilityMilestoneCalibrationAwardService
  CERTIFICATION_NOTE = 'Initial ability milestone calibration'

  def self.call(...) = new(...).call

  def initialize(item:, official_level:, certifying_teammate:, created_by_person:, organization:)
    @item = item
    @official_level = official_level.to_i
    @certifying_teammate = certifying_teammate
    @created_by_person = created_by_person
    @organization = organization
    @teammate = item.ability_milestone_calibration.teammate
  end

  def call
    unless (0..5).cover?(@official_level)
      return Result.err('Official milestone level must be between 0 and 5.')
    end

    if @item.awarded?
      return Result.err('This ability has already been awarded in this calibration pass.')
    end

    unless @item.ready_for_review?
      return Result.err('Both employee and manager must rate this ability before awarding.')
    end

    ApplicationRecord.transaction do
      if @official_level.positive?
        apply_milestones!
      end

      @item.update!(
        official_milestone_level: @official_level,
        awarded_at: Time.current,
        awarded_by_teammate: @certifying_teammate
      )

      EngagementHealth.schedule_refresh_for(@teammate.id) if @official_level.positive?
      Result.ok(@item.reload)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages.join(', '))
  rescue StandardError => e
    Result.err("Calibration award failed: #{e.message}")
  end

  private

  def apply_milestones!
    company = @organization.root_company || @organization
    ability = Ability.find_by(id: @item.ability_id, company: company)
    raise StandardError, 'Ability not found.' unless ability

    current_levels = @teammate.teammate_milestones.where(ability_id: ability.id).pluck(:milestone_level).map(&:to_i)
    to_add = (1..@official_level).to_a - current_levels
    return if to_add.empty?

    highest_new = to_add.max
    to_add.sort.each do |level|
      company_visible = (level == highest_new)
      create_milestone!(ability:, level:, company_visible:)
    end
  end

  def create_milestone!(ability:, level:, company_visible:)
    published_at = company_visible ? Time.current : nil
    published_by_teammate_id = company_visible ? @certifying_teammate.id : nil

    teammate_milestone = TeammateMilestone.create!(
      teammate: @teammate,
      ability: ability,
      milestone_level: level,
      certifying_teammate: @certifying_teammate,
      attained_at: Date.current,
      certification_note: CERTIFICATION_NOTE,
      published_at: published_at,
      published_by_teammate_id: published_by_teammate_id
    )

    return unless company_visible

    om_result = ObservableMoments::CreateAbilityMilestoneMomentService.call(
      teammate_milestone: teammate_milestone,
      created_by: @created_by_person
    )
    raise StandardError, om_result.error.to_s unless om_result.ok?
  end
end
