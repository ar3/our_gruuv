# frozen_string_literal: true

module MilestoneAwards
  module ModeratorAuthorization
    module_function

    def can_moderate?(teammate:, milestone_award:)
      return false if teammate.blank? || milestone_award.blank?
      return true if teammate.person&.og_admin?
      return true if teammate.can_manage_employment?
      return true if milestone_award.ability.maintained_by?(teammate)

      false
    end
  end
end
