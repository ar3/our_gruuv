# frozen_string_literal: true

class MilestoneAwardPolicy < ApplicationPolicy
  def show?
    return false unless viewing_teammate
    return true if viewing_teammate.person&.og_admin?
    return true if record.certifying_teammate_id == viewing_teammate.id
    return true if record.teammate_id == viewing_teammate.id && record.effective?
    return true if invitee?
    return true if viewing_teammate.in_managerial_hierarchy_of?(record.teammate)
    return true if MilestoneAwards::ModeratorAuthorization.can_moderate?(
      teammate: viewing_teammate,
      milestone_award: record
    )

    false
  end

  # Award attempts on teammate ability history: awarder, hierarchy, manage employment.
  # Recipient never sees attempts here (even after an award becomes effective).
  def view_award_attempt_history?
    return false unless viewing_teammate
    return false if record.teammate_id == viewing_teammate.id
    return true if viewing_teammate.person&.og_admin?
    return true if record.certifying_teammate_id == viewing_teammate.id
    return true if viewing_teammate.can_manage_employment?
    return true if viewing_teammate.in_managerial_hierarchy_of?(record.teammate)

    false
  end

  def cosign?
    return false unless viewing_teammate
    return false unless record.cosigner_signed_at.blank?
    return false if record.certifying_teammate_id == viewing_teammate.id
    return true if invitee_open?
    return true if MilestoneAwards::ModeratorAuthorization.can_moderate?(
      teammate: viewing_teammate,
      milestone_award: record
    ) && (record.skipped_awaiting_moderation? || record.requires_cosign_after_moderation? || record.pending_cosign?)

    false
  end

  def decline?
    invitee_open? && record.pending_cosign?
  end

  def request_cosign?
    return false unless viewing_teammate
    return false unless record.certifying_teammate_id == viewing_teammate.id
    return true if record.requires_cosign_after_moderation?
    return true if record.pending_cosign? && record.all_cosign_invitees_declined?

    false
  end

  def require_cosign?
    return false unless viewing_teammate
    record.skipped_awaiting_moderation? &&
      MilestoneAwards::ModeratorAuthorization.can_moderate?(
        teammate: viewing_teammate,
        milestone_award: record
      )
  end

  def view_cosign_responses?
    return false unless viewing_teammate
    return true if viewing_teammate.person&.og_admin?
    return true if record.certifying_teammate_id == viewing_teammate.id
    return true if viewing_teammate.can_manage_employment?

    false
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

  private

  def invitee?
    record.cosign_invites.exists?(invitee_teammate_id: viewing_teammate.id)
  end

  def invitee_open?
    return false unless viewing_teammate

    record.cosign_invites.open.exists?(invitee_teammate_id: viewing_teammate.id)
  end
end
