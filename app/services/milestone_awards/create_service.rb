# frozen_string_literal: true

module MilestoneAwards
  # Creates a MilestoneAward (normal or calibration) with typed awarder signature,
  # either requesting co-sign (held) or skipping (released + flagged).
  class CreateService
    def self.call(...) = new(...).call

    def initialize(
      teammate:,
      ability:,
      official_level:,
      certifying_teammate:,
      created_by_person:,
      organization:,
      source:,
      awarder_typed_name:,
      skip_cosign:,
      cosign_invitee_ids: [],
      certification_note: nil,
      privacy_level: "company",
      calibration_item: nil
    )
      @teammate = teammate
      @ability = ability
      @official_level = official_level.to_i
      @certifying_teammate = certifying_teammate
      @created_by_person = created_by_person
      @organization = organization
      @source = source.to_s
      @awarder_typed_name = awarder_typed_name
      @skip_cosign = ActiveModel::Type::Boolean.new.cast(skip_cosign)
      @cosign_invitee_ids = Array(cosign_invitee_ids).map(&:to_i).uniq.reject(&:zero?)
      @certification_note = certification_note.to_s.strip.presence
      @privacy_level = privacy_level.to_s.presence || "company"
      @calibration_item = calibration_item
    end

    def call
      return Result.err("Official Milestone must be between 1 and 5.") unless (1..5).cover?(@official_level)
      return Result.err("Source must be normal or calibration.") unless MilestoneAward::SOURCES.include?(@source)
      return Result.err("Choose at least one co-signer, or skip co-sign.") if !@skip_cosign && @cosign_invitee_ids.empty?
      return Result.err("Cannot both skip and invite co-signers.") if @skip_cosign && @cosign_invitee_ids.any?

      if @teammate.teammate_milestones.exists?(ability: @ability, milestone_level: @official_level)
        return Result.err("This milestone has already been awarded.")
      end

      if pending_duplicate?
        return Result.err("A co-sign request for this milestone is already pending.")
      end

      ApplicationRecord.transaction do
        award = build_award!
        unless @skip_cosign
          create_invites!(award)
          MilestoneAwards::NotifyCosignInviteesService.call(milestone_award: award)
        end

        if @skip_cosign
          apply = ApplyMilestonesService.call(milestone_award: award, created_by_person: @created_by_person)
          raise StandardError, apply.error.to_s unless apply.ok?
          EngagementHealth.schedule_refresh_for(@teammate.id)
        end

        Result.ok(award.reload)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.join(", "))
    rescue StandardError => e
      Result.err(e.message)
    end

    private

    def pending_duplicate?
      MilestoneAward.pending_cosign
        .or(MilestoneAward.requires_cosign_after_moderation)
        .exists?(teammate_id: @teammate.id, ability_id: @ability.id, official_milestone_level: @official_level)
    end

    def build_award!
      now = Time.current
      MilestoneAward.create!(
        teammate: @teammate,
        ability: @ability,
        official_milestone_level: @official_level,
        source: @source,
        certifying_teammate: @certifying_teammate,
        organization: @organization,
        ability_milestone_calibration_item: @calibration_item,
        certification_note: @certification_note,
        privacy_level: @privacy_level,
        awarder_typed_name: @awarder_typed_name,
        awarder_signed_at: now,
        cosign_requested_at: @skip_cosign ? nil : now,
        awarder_skipped_cosign_at: @skip_cosign ? now : nil
      )
    end

    def create_invites!(award)
      invalid = @cosign_invitee_ids - eligible_invitee_ids
      raise StandardError, "One or more co-signers are not eligible." if invalid.any?

      @cosign_invitee_ids.each do |invitee_id|
        award.cosign_invites.create!(invitee_teammate_id: invitee_id)
      end
    end

    def eligible_invitee_ids
      CompanyTeammate
        .where(organization: @organization, last_terminated_at: nil)
        .where.not(id: [@teammate.id, @certifying_teammate.id])
        .pluck(:id)
    end
  end
end
