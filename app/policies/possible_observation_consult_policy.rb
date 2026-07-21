# frozen_string_literal: true

class PossibleObservationConsultPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization_id: viewing_teammate.organization_id)
    end
  end

  def index?
    viewing_teammate.present? && !terminated?
  end

  def show?
    index? && (admin_bypass? || record.creator_company_teammate_id == viewing_teammate.id)
  end

  def create?
    index?
  end

  def new?
    create?
  end

  def import_google_meet?
    create?
  end

  def import_zoom?
    create?
  end

  def update?
    show?
  end

  def confirm_teammates?
    show? && record.extraction_status.in?(%w[ready failed])
  end

  def extract?
    show? && record.people_confirmed? && record.extraction_status.in?(%w[ready failed completed])
  end

  def re_extract?
    extract?
  end

  def extraction_status?
    show?
  end

  def create_draft_observations?
    show? && record.extraction_status == "completed"
  end

  private

  def terminated?
    viewing_teammate.respond_to?(:terminated?) && viewing_teammate.terminated?
  end
end
