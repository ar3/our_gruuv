# frozen_string_literal: true

# Org-scoped profile for a Person who has never been a teammate of this company.
class ExternalPersonPolicy < ApplicationPolicy
  def show?
    return false unless viewing_teammate
    return false if viewing_teammate.terminated?

    org = viewing_teammate.organization
    company = org.root_company || org
    return false if teammate_record_for?(record, org) || teammate_record_for?(record, company)

    true
  end

  private

  def teammate_record_for?(person, organization)
    return false if person.blank? || organization.blank?

    person.company_teammates.exists?(organization_id: organization.id)
  end
end
