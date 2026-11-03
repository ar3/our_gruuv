# frozen_string_literal: true

class SlackPossibleObservationPolicy < ApplicationPolicy
  def show?
    return false unless viewing_teammate
    return false if viewing_teammate.terminated?
    return false unless can_view_subject_ogos?

    # Private/DM visibility stays searcher-only even for admins.
    record.visible_to?(viewing_teammate)
  end

  def dismiss?
    show?
  end

  def promote?
    show?
  end

  private

  def can_view_subject_ogos?
    subject = record.subject_company_teammate
    return false if subject.nil?

    link = subject.one_on_one_link || OneOnOneLink.new(teammate: subject)
    OneOnOneLinkPolicy.new(pundit_user, link).ogos?
  end
end
