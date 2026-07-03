# frozen_string_literal: true

# Applies bulk milestone level targets per ability: removes attainments above target,
# adds missing 1..target with privacy rules and observable moments (highest new only).
class BulkMilestoneAwardApplyService
  CERTIFICATION_NOTE = 'Bulk Milestone Adjustment'

  # @return [Array<Hash>] one entry per catalog row: :row, :target_level, :existing_levels, :removing_levels, :adding_levels
  def self.preview(teammate:, catalog_rows:, selections_by_ability_id:)
    sel = selections_by_ability_id.transform_keys(&:to_i).transform_values { |v| v.to_i }
    catalog_rows.map do |row|
      aid = row[:ability_id]
      target = sel.fetch(aid, 0)
      current = teammate.teammate_milestones.where(ability_id: aid).pluck(:milestone_level).map(&:to_i).uniq.sort
      desired = target.positive? ? (1..target).to_a : []
      {
        row: row,
        target_level: target,
        existing_levels: current,
        removing_levels: (current - desired).sort.reverse,
        adding_levels: (desired - current).sort
      }
    end
  end

  def self.call(...) = new(...).call

  def initialize(teammate:, organization:, selections_by_ability_id:, certifying_teammate:, created_by_person:)
    @teammate = teammate
    @organization = organization
    @selections_by_ability_id = selections_by_ability_id.transform_keys(&:to_i).transform_values { |v| v.to_i }
    @certifying_teammate = certifying_teammate
    @created_by_person = created_by_person
  end

  def call
    allowed_ids = BulkMilestoneAwardAbilitiesCatalog.ability_ids_for(teammate: @teammate, organization: @organization)
    return Result.err('No abilities are available for this teammate in bulk milestone adjustment.') if allowed_ids.empty?

    missing = allowed_ids - @selections_by_ability_id.keys
    return Result.err('Missing milestone selection for one or more abilities.') if missing.any?

    ApplicationRecord.transaction do
      allowed_ids.each do |ability_id|
        target_level = @selections_by_ability_id[ability_id]
        unless (0..5).cover?(target_level)
          return Result.err("Invalid milestone selection for ability #{ability_id}.")
        end

        apply_for_ability!(ability_id, target_level)
      end

      CheckInHealthCacheRefreshSchedule.schedule_refresh_for(@teammate.id)
      EngagementHealth.schedule_refresh_for(@teammate.id)
      Result.ok(:applied)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages.join(', '))
  rescue StandardError => e
    Result.err("Bulk milestone adjustment failed: #{e.message}")
  end

  private

  def apply_for_ability!(ability_id, target_level)
    company = @organization.root_company || @organization
    ability = Ability.find_by(id: ability_id, company: company)
    return unless ability

    current_levels = @teammate.teammate_milestones.where(ability_id: ability_id).pluck(:milestone_level).map(&:to_i).uniq.sort
    desired_levels = target_level.positive? ? (1..target_level).to_a : []

    to_remove = current_levels - desired_levels
    to_add = desired_levels - current_levels

    to_remove.sort.reverse_each { |level| remove_milestone!(ability_id, level) }

    return if to_add.empty?

    highest_new = to_add.max
    to_add.sort.each do |level|
      company_visible = (level == highest_new)
      create_milestone!(ability:, level:, company_visible:)
    end
  end

  def remove_milestone!(ability_id, level)
    milestone = @teammate.teammate_milestones.find_by(ability_id: ability_id, milestone_level: level)
    return unless milestone

    moment = milestone.observable_moment
    if moment&.observed?
      milestone.delete
    else
      milestone.destroy!
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
