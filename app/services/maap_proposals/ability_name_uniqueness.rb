# frozen_string_literal: true

module MaapProposals
  class AbilityNameUniqueness
    Result = Data.define(:taken?, :conflicting_ability, :apply_name, :message)

    def self.call(organization:, proposed_name:, excluding_ability: nil, mode: :edit)
      new(
        organization: organization,
        proposed_name: proposed_name,
        excluding_ability: excluding_ability,
        mode: mode
      ).call
    end

    def self.unique_name_for_create(organization:, proposed_name:)
      base = proposed_name.to_s.strip
      return base if base.blank?

      candidate = base
      n = 0
      while conflicting_scope(organization).where("LOWER(TRIM(name)) = ?", candidate.downcase).exists?
        n += 1
        candidate = n == 1 ? "#{base} (duplicate)" : "#{base} (duplicate #{n})"
      end
      candidate
    end

    def self.conflicting_scope(organization)
      Ability.where(company_id: organization.id)
    end

    def initialize(organization:, proposed_name:, excluding_ability:, mode:)
      @organization = organization
      @proposed_name = proposed_name.to_s.strip
      @excluding_ability = excluding_ability
      @mode = mode.to_sym
    end

    def call
      if @proposed_name.blank?
        return Result.new(taken?: false, conflicting_ability: nil, apply_name: @proposed_name, message: nil)
      end

      conflict = find_conflict
      unless conflict
        return Result.new(
          taken?: false,
          conflicting_ability: nil,
          apply_name: @proposed_name,
          message: nil
        )
      end

      apply_name = if @mode == :create
        self.class.unique_name_for_create(organization: @organization, proposed_name: @proposed_name)
      else
        @proposed_name
      end

      Result.new(
        taken?: true,
        conflicting_ability: conflict,
        apply_name: apply_name,
        message: message_for(conflict, apply_name)
      )
    end

    private

    def find_conflict
      scope = self.class.conflicting_scope(@organization)
      scope = scope.where.not(id: @excluding_ability.id) if @excluding_ability
      scope.where("LOWER(TRIM(name)) = ?", @proposed_name.downcase).order(:id).first
    end

    def message_for(conflict, apply_name)
      if @mode == :create
        "Name \"#{@proposed_name}\" is already used by \"#{conflict.name}\" (##{conflict.id}). " \
          "Applying will create this Ability as \"#{apply_name}\"."
      else
        "Name \"#{@proposed_name}\" is already used by another Ability " \
          "(\"#{conflict.name}\" ##{conflict.id}). Applying may fail until the name is unique."
      end
    end
  end
end
