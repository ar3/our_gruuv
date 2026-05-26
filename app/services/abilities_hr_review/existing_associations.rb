# frozen_string_literal: true

module AbilitiesHrReview
  class ExistingAssociations
    def self.list(organization:, ability_id:)
      new(organization: organization, ability_id: ability_id).list
    end

    def initialize(organization:, ability_id:)
      @organization = organization
      @ability_id = ability_id
    end

    def list
      return [] if @ability_id.blank?

      ability = Ability.find_by(id: @ability_id, company_id: @organization.id)
      return [] unless ability

      ability.assignment_abilities.includes(:assignment).map do |aa|
        {
          'assignment_id' => aa.assignment_id,
          'assignment_title' => aa.assignment.title,
          'milestone_level' => aa.milestone_level
        }
      end
    end
  end
end
