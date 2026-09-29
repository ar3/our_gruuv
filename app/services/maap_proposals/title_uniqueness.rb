# frozen_string_literal: true

module MaapProposals
  # Case-insensitive title collision check within a company.
  class TitleUniqueness
    Result = Data.define(
      :taken?,
      :conflicting_assignment,
      :apply_title,
      :message
    )

    def self.call(organization:, proposed_title:, excluding_assignment: nil, mode: :create)
      new(
        organization: organization,
        proposed_title: proposed_title,
        excluding_assignment: excluding_assignment,
        mode: mode
      ).call
    end

    def self.unique_title_for_create(organization:, proposed_title:)
      base = proposed_title.to_s.strip
      return base if base.blank?

      candidate = base
      n = 0
      while conflicting_scope(organization).where("LOWER(TRIM(title)) = ?", candidate.downcase).exists?
        n += 1
        candidate = n == 1 ? "#{base} (duplicate)" : "#{base} (duplicate #{n})"
      end
      candidate
    end

    def self.conflicting_scope(organization)
      Assignment.where(company_id: organization.id)
    end

    def initialize(organization:, proposed_title:, excluding_assignment:, mode:)
      @organization = organization
      @proposed_title = proposed_title.to_s.strip
      @excluding_assignment = excluding_assignment
      @mode = mode.to_sym
    end

    def call
      return Result.new(taken?: false, conflicting_assignment: nil, apply_title: @proposed_title, message: nil) if @proposed_title.blank?

      conflict = find_conflict
      unless conflict
        return Result.new(
          taken?: false,
          conflicting_assignment: nil,
          apply_title: @proposed_title,
          message: nil
        )
      end

      apply_title = if @mode == :create
        self.class.unique_title_for_create(organization: @organization, proposed_title: @proposed_title)
      else
        @proposed_title
      end

      Result.new(
        taken?: true,
        conflicting_assignment: conflict,
        apply_title: apply_title,
        message: message_for(conflict, apply_title)
      )
    end

    private

    def find_conflict
      scope = self.class.conflicting_scope(@organization)
      scope = scope.where.not(id: @excluding_assignment.id) if @excluding_assignment
      scope.where("LOWER(TRIM(title)) = ?", @proposed_title.downcase).order(:id).first
    end

    def message_for(conflict, apply_title)
      if @mode == :create
        "Title \"#{@proposed_title}\" is already used by \"#{conflict.title}\" (##{conflict.id}). " \
          "Applying will create this Assignment as \"#{apply_title}\"."
      else
        "Title \"#{@proposed_title}\" is already used by another Assignment " \
          "(\"#{conflict.title}\" ##{conflict.id}). Applying may fail until the title is unique."
      end
    end
  end
end
