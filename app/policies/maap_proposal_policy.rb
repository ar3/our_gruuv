# frozen_string_literal: true

class MaapProposalPolicy < ApplicationPolicy
  def index?
    admin_bypass? || viewing_teammate.present?
  end

  def show?
    admin_bypass? || same_organization?
  end

  def create?
    admin_bypass? || viewing_teammate.present?
  end

  def update?
    admin_bypass? || (same_organization? && proposer? && record.editable?)
  end

  def destroy?
    admin_bypass? || (same_organization? && proposer? && record.deletable?)
  end

  def submit?
    admin_bypass? || (same_organization? && proposer? && record.submittable?)
  end

  def apply?
    return false unless record_present? && (admin_bypass? || same_organization?)

    if record.create_kind?
      can_create_proposable?
    else
      can_update_proposable?
    end
  end

  def reject?
    apply?
  end

  def markdown?
    show?
  end

  def markdown_template?
    index?
  end

  def upload_markdown?
    create?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate

      if viewing_teammate.person&.og_admin?
        scope.all
      else
        scope.where(organization_id: viewing_teammate.organization_id)
      end
    end
  end

  private

  def record_present?
    record.is_a?(MaapProposal)
  end

  def same_organization?
    return false unless viewing_teammate && record_present?

    record.organization_id == viewing_teammate.organization_id
  end

  def proposer?
    return false unless viewing_teammate && record_present?

    record.proposer_id == viewing_teammate.id
  end

  def can_update_proposable?
    return false unless record_present? && record.proposable

    Pundit.policy(pundit_user, record.proposable).update?
  end

  def can_create_proposable?
    return false unless record_present?

    if record.ability_create?
      Pundit.policy(pundit_user, Ability.new(company: record.organization)).create?
    else
      Pundit.policy(pundit_user, Assignment.new(company: record.organization)).create?
    end
  end
end
