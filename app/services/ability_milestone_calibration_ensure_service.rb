# frozen_string_literal: true

# Finds or creates the teammate's calibration and syncs items to C-suggested abilities at M0.
class AbilityMilestoneCalibrationEnsureService
  def self.call(...) = new(...).call

  def initialize(teammate:, organization:)
    @teammate = teammate
    @organization = organization
  end

  def call
    calibration = AbilityMilestoneCalibration.find_or_create_by!(teammate_id: @teammate.id)
    sync_items!(calibration)
    calibration.reload
    Result.ok(calibration)
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages.join(', '))
  end

  # After a pass where some abilities were officially set to 0, reopen them for another rating cycle.
  def self.reopen_m0_for_rating!(calibration:, organization:)
    new(teammate: calibration.teammate, organization: organization).reopen_m0_for_rating!(calibration)
  end

  def reopen_m0_for_rating!(calibration)
    sync_items!(calibration)
    m0_ids = m0_ability_ids
    calibration.items.where(ability_id: m0_ids).where.not(awarded_at: nil).find_each do |item|
      next if item.official_milestone_level.to_i >= 1

      item.update!(
        awarded_at: nil,
        awarded_by_teammate: nil,
        official_milestone_level: nil
      )
    end
    Result.ok(calibration.reload)
  end

  private

  def sync_items!(calibration)
    catalog_ids = AbilityMilestoneCalibrationAbilitiesCatalog.ability_ids_for(
      teammate: @teammate,
      organization: @organization
    ).to_a
    m0_ids = m0_ability_ids & catalog_ids

    # Abilities with real teammate milestones no longer need open rating rows.
    # Keep awarded calibration rows that have both ratings as history.
    awarded_ability_ids = @teammate.teammate_milestones.distinct.pluck(:ability_id)
    calibration.items.where(ability_id: awarded_ability_ids).find_each do |item|
      next if item.awarded? && item.both_rated?

      item.destroy!
    end

    m0_ids.each do |ability_id|
      calibration.items.find_or_create_by!(ability_id: ability_id)
    end

    # Remove stale open items no longer in the M0 catalog; keep awarded history.
    stale = calibration.items.where.not(ability_id: m0_ids)
    stale.find_each do |item|
      next if item.awarded? && item.both_rated?

      item.destroy!
    end
  end

  def m0_ability_ids
    catalog = AbilityMilestoneCalibrationAbilitiesCatalog.call(
      teammate: @teammate,
      organization: @organization
    )
    catalog.select { |r| r[:highest_awarded].to_i < 1 }.map { |r| r[:ability_id] }.to_set
  end
end
