# frozen_string_literal: true

module MilestoneAwards
  class DeclineCosignService
    def self.call(...) = new(...).call

    def initialize(milestone_award:, invitee_teammate:, reason:)
      @award = milestone_award
      @invitee_teammate = invitee_teammate
      @reason = reason.to_s.strip
    end

    def call
      return Result.err("This award is not awaiting a co-sign.") unless @award.pending_cosign?
      return Result.err("Please explain why you are declining.") if @reason.blank?

      invite = @award.cosign_invites.open.find_by(invitee_teammate_id: @invitee_teammate.id)
      return Result.err("You were not invited to co-sign this award.") if invite.blank?

      invite.update!(declined_at: Time.current, decline_reason: @reason)
      Result.ok(@award.reload)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.join(", "))
    end
  end
end
