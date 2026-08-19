# frozen_string_literal: true

class TalentDensityStance < ApplicationRecord
  has_paper_trail

  belongs_to :company_teammate, class_name: "CompanyTeammate"
  belongs_to :company, class_name: "Organization"

  enum :stance, {
    take_the_swap: "take_the_swap",
    fine_either_way: "fine_either_way",
    try_to_avoid_the_swap: "try_to_avoid_the_swap"
  }, prefix: true

  before_validation :set_company_from_teammate

  validates :company_teammate_id, uniqueness: true
  validates :stance, inclusion: { in: stances.keys }, allow_nil: true

  def display_name
    person = company_teammate&.person
    return "Talent Density ##{id}" unless person

    "Talent Density — #{person.display_name.presence || person.casual_name}"
  end

  private

  def set_company_from_teammate
    self.company_id ||= company_teammate&.organization_id
  end
end
