# frozen_string_literal: true

# Org-scoped profile for a Person who is not an active teammate of this company.
class ExternalPersonPolicy < ApplicationPolicy
  def show?
    return false unless viewing_teammate
    return false if viewing_teammate.terminated?

    org = viewing_teammate.organization
    company = org.root_company || org
    return false if record.active_teammate_of?(org) || record.active_teammate_of?(company)

    true
  end
end
