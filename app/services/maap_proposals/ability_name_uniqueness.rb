# frozen_string_literal: true

module MaapProposals
  class AbilityNameUniqueness
    Result = Data.define(:taken?, :conflicting_ability, :message)

    def self.call(organization:, proposed_name:, excluding_ability: nil)
      new(
        organization: organization,
        proposed_name: proposed_name,
        excluding_ability: excluding_ability
      ).call
    end

    def initialize(organization:, proposed_name:, excluding_ability:)
      @organization = organization
      @proposed_name = proposed_name.to_s.strip
      @excluding_ability = excluding_ability
    end

    def call
      return Result.new(taken?: false, conflicting_ability: nil, message: nil) if @proposed_name.blank?

      scope = Ability.where(company_id: @organization.id)
      scope = scope.where.not(id: @excluding_ability.id) if @excluding_ability
      conflict = scope.where("LOWER(TRIM(name)) = ?", @proposed_name.downcase).order(:id).first
      return Result.new(taken?: false, conflicting_ability: nil, message: nil) unless conflict

      Result.new(
        taken?: true,
        conflicting_ability: conflict,
        message: "Name \"#{@proposed_name}\" is already used by another Ability " \
                 "(\"#{conflict.name}\" ##{conflict.id}). Applying may fail until the name is unique."
      )
    end
  end
end
