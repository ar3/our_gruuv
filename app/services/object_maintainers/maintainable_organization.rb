# frozen_string_literal: true

module ObjectMaintainers
  module MaintainableOrganization
    module_function

    def resolve(maintainable)
      case maintainable
      when Assignment, Ability
        maintainable.company
      when Position
        maintainable.title&.company
      end
    end
  end
end
