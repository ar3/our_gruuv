# frozen_string_literal: true

module MilestoneAwards
  # Creates TeammateMilestone rows 1..official for a released MilestoneAward bundle.
  class ApplyMilestonesService
    def self.call(...) = new(...).call

    def initialize(milestone_award:, created_by_person:)
      @award = milestone_award
      @created_by_person = created_by_person
    end

    def call
      return Result.ok(@award) if @award.teammate_milestones.exists?

      unless @award.released?
        return Result.err("Milestones can only be applied when the award is released.")
      end

      ApplicationRecord.transaction do
        create_bundle!
        Result.ok(@award.reload)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.join(", "))
    rescue StandardError => e
      Result.err(e.message)
    end

    private

    def create_bundle!
      teammate = @award.teammate
      ability = @award.ability
      official = @award.official_milestone_level
      current_levels = teammate.teammate_milestones.where(ability_id: ability.id).pluck(:milestone_level).map(&:to_i)
      desired = @award.source == "calibration" ? (1..official).to_a : [official]
      to_add = desired - current_levels
      return if to_add.empty?

      highest_new = to_add.max
      company_visible_allowed = @award.privacy_level == "company" && !@award.pending_cosign?

      to_add.sort.each do |level|
        company_visible = company_visible_allowed && (level == highest_new) && @award.effective?
        create_milestone!(ability:, level:, company_visible:)
      end
    end

    def create_milestone!(ability:, level:, company_visible:)
      published_at = company_visible ? Time.current : nil
      published_by = company_visible ? @award.certifying_teammate_id : nil

      teammate_milestone = TeammateMilestone.create!(
        teammate: @award.teammate,
        ability: ability,
        milestone_level: level,
        certifying_teammate: @award.certifying_teammate,
        attained_at: Date.current,
        certification_note: @award.certification_note,
        published_at: published_at,
        published_by_teammate_id: published_by,
        milestone_award: @award
      )

      return unless company_visible

      om_result = ObservableMoments::CreateAbilityMilestoneMomentService.call(
        teammate_milestone: teammate_milestone,
        created_by: @created_by_person
      )
      raise StandardError, om_result.error.to_s unless om_result.ok?
    end
  end
end
