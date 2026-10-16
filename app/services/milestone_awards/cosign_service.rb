# frozen_string_literal: true

module MilestoneAwards
  class CosignService
    include TypedNameSignature

    def self.call(...) = new(...).call

    def initialize(milestone_award:, cosigning_teammate:, typed_name:, reason:)
      @award = milestone_award
      @cosigning_teammate = cosigning_teammate
      @typed_name = typed_name
      @reason = reason.to_s.strip
    end

    def call
      return Result.err("This award is not awaiting a co-sign.") unless awaiting_cosign?
      return Result.err("You cannot co-sign an award you created.") if @cosigning_teammate.id == @award.certifying_teammate_id
      return Result.err("Please explain why you are co-signing.") if @reason.blank?
      return Result.err("Typed name must match your full name.") unless typed_name_matches?(@typed_name, @cosigning_teammate.person)

      invite = @award.cosign_invites.open.find_by(invitee_teammate_id: @cosigning_teammate.id)
      moderator_ok = moderator_can_cosign?
      return Result.err("You were not invited to co-sign this award.") if invite.blank? && !moderator_ok

      ApplicationRecord.transaction do
        @award.update!(
          cosigning_teammate: @cosigning_teammate,
          cosigner_typed_name: @typed_name,
          cosigner_reason: @reason,
          cosigner_signed_at: Time.current,
          moderator_requires_cosign_at: nil
        )

        unless @award.teammate_milestones.exists?
          # Fresh release, or after moderator tore down skip-created milestones.
          apply = ApplyMilestonesService.call(
            milestone_award: @award,
            created_by_person: @cosigning_teammate.person
          )
          raise StandardError, apply.error.to_s unless apply.ok?
          EngagementHealth.schedule_refresh_for(@award.teammate_id)
        else
          restore_publish_if_needed!
        end

        ConvertLeftoverInvitesToFeedbackService.call(milestone_award: @award)
        Result.ok(@award.reload)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.join(", "))
    rescue StandardError => e
      Result.err(e.message)
    end

    private

    def awaiting_cosign?
      @award.pending_cosign? || @award.requires_cosign_after_moderation? || @award.skipped_awaiting_moderation?
    end

    def moderator_can_cosign?
      MilestoneAwards::ModeratorAuthorization.can_moderate?(
        teammate: @cosigning_teammate,
        milestone_award: @award
      )
    end

    def restore_publish_if_needed!
      return unless @award.privacy_level == "company"

      primary = @award.primary_teammate_milestone
      return if primary.blank? || primary.published?

      primary.update!(
        published_at: Time.current,
        published_by_teammate_id: @award.certifying_teammate_id
      )
    end
  end
end
