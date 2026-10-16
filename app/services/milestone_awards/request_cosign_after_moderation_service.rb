# frozen_string_literal: true

module MilestoneAwards
  # After moderator requires co-sign, awarder invites co-signers (cannot skip again).
  class RequestCosignAfterModerationService
    def self.call(...) = new(...).call

    def initialize(milestone_award:, awarder_teammate:, cosign_invitee_ids:)
      @award = milestone_award
      @awarder_teammate = awarder_teammate
      @cosign_invitee_ids = Array(cosign_invitee_ids).map(&:to_i).uniq.reject(&:zero?)
    end

    def call
      return Result.err("Only the original awarder can request co-sign.") unless @awarder_teammate.id == @award.certifying_teammate_id
      return Result.err("This award is not awaiting a co-sign request.") unless can_request_additional_cosigners?
      return Result.err("Choose at least one co-signer.") if @cosign_invitee_ids.empty?

      invalid = @cosign_invitee_ids - eligible_invitee_ids
      return Result.err("One or more co-signers are not eligible.") if invalid.any?

      ApplicationRecord.transaction do
        @award.update!(cosign_requested_at: Time.current) if @award.cosign_requested_at.blank?

        newly_opened_ids = []
        @cosign_invitee_ids.each do |invitee_id|
          invite = @award.cosign_invites.find_or_initialize_by(invitee_teammate_id: invitee_id)
          if invite.persisted? && (invite.declined? || invite.converted_to_feedback?)
            invite.update!(declined_at: nil, decline_reason: nil, converted_to_feedback_at: nil, feedback_request: nil)
            newly_opened_ids << invitee_id
          elsif invite.new_record?
            invite.save!
            newly_opened_ids << invitee_id
          else
            invite.save!
            newly_opened_ids << invitee_id
          end
        end

        MilestoneAwards::NotifyCosignInviteesService.call(
          milestone_award: @award,
          invitee_teammate_ids: newly_opened_ids
        )
        Result.ok(@award.reload)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.join(", "))
    end

    private

    def can_request_additional_cosigners?
      return true if @award.requires_cosign_after_moderation?
      return true if @award.pending_cosign? && @award.all_cosign_invitees_declined?

      false
    end

    def eligible_invitee_ids
      CompanyTeammate
        .where(organization_id: @award.organization_id, last_terminated_at: nil)
        .where.not(id: [@award.teammate_id, @award.certifying_teammate_id])
        .pluck(:id)
    end
  end
end
