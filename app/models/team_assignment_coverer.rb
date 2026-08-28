# frozen_string_literal: true

class TeamAssignmentCoverer < ApplicationRecord
  belongs_to :team_assignment_need
  belongs_to :company_teammate

  validates :company_teammate_id, uniqueness: { scope: :team_assignment_need_id }
  validate :coverer_belongs_to_team_company

  delegate :team, :assignment, to: :team_assignment_need

  private

  def coverer_belongs_to_team_company
    return if team_assignment_need.blank? || company_teammate.blank?
    return if company_teammate.organization_id == team_assignment_need.team.company_id

    errors.add(:company_teammate, "must belong to the same company as the team")
  end
end
