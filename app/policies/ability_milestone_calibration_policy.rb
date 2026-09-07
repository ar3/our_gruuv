# frozen_string_literal: true

class AbilityMilestoneCalibrationPolicy < ApplicationPolicy
  def show?
    return true if admin_bypass?

    participant?
  end

  def update?
    show?
  end

  def review?
    show?
  end

  def award?
    return true if admin_bypass?

    can_award_to_subject?
  end

  def reopen?
    return true if admin_bypass?

    can_award_to_subject? || subject?
  end

  def entry_control?
    return true if admin_bypass?

    participant? && catalog_has_abilities?
  end

  private

  def subject_teammate
    record.teammate
  end

  def subject?
    viewing_teammate.present? && viewing_teammate.id == subject_teammate.id
  end

  def participant?
    return false if viewing_teammate.blank?
    return false if viewing_teammate.terminated?

    subject? || can_award_to_subject? || manager_of_subject?
  end

  def manager_of_subject?
    return false if viewing_teammate.blank?

    CompanyTeammatePolicy.new(pundit_user, subject_teammate).manager?
  end

  def can_award_to_subject?
    return false if viewing_teammate.blank?
    return false if viewing_teammate.terminated?
    return false unless TeammateMilestonePolicy.new(pundit_user, TeammateMilestone).create?

    TeammateMilestoneRecipientEligibilityQuery.new(
      awarding_teammate: viewing_teammate,
      organization: subject_teammate.organization
    ).eligible_to_award?(subject_teammate)
  end

  def catalog_has_abilities?
    AbilityMilestoneCalibrationAbilitiesCatalog.ability_ids_for(
      teammate: subject_teammate,
      organization: subject_teammate.organization
    ).any?
  end
end
