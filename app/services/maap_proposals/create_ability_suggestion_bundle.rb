# frozen_string_literal: true

module MaapProposals
  # Spawns one or more Ability create/edit drafts from MAAP Suggestion chat.
  class CreateAbilitySuggestionBundle
    def self.call(organization:, proposer:, bundle:)
      new(organization: organization, proposer: proposer, bundle: bundle).call
    end

    def initialize(organization:, proposer:, bundle:)
      @organization = organization
      @proposer = proposer
      @bundle = (bundle || {}).deep_stringify_keys
    end

    def call
      abilities = Array(@bundle["abilities"])
      return Result.err("bundle.abilities must include at least one ability") if abilities.empty?

      created = []
      primary = nil

      ApplicationRecord.transaction do
        abilities.each do |raw|
          next unless raw.is_a?(Hash)

          row = raw.deep_stringify_keys
          proposal = upsert_ability!(row, created)
          primary ||= proposal
        end
      end

      Result.ok(
        primary_proposal: primary,
        proposals: created,
        redirect_path: redirect_for(primary)
      )
    rescue BundleFailed => e
      Result.err(e.messages)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages)
    end

    private

    class BundleFailed < StandardError
      attr_reader :messages

      def initialize(messages)
        @messages = Array(messages)
        super(@messages.join(", "))
      end
    end

    def upsert_ability!(row, created)
      mode = row["mode"].to_s
      if mode == "edit" || mode == "existing"
        ability = find_ability(row)
        raise BundleFailed, "Could not find ability #{row['name'] || row['path']}" if ability.nil?
        return nil if mode == "existing"

        proposal = create_ability_edit!(ability, row)
        created << proposal
        proposal
      else
        result = CreateAbilityCreateDraft.call(
          organization: @organization,
          proposer: @proposer,
          payload: ability_create_payload(row)
        )
        raise BundleFailed, result.error unless result.ok?

        created << result.value
        result.value
      end
    end

    def create_ability_edit!(ability, row)
      current = AbilityPayload.from_ability(ability).to_h
      merged = current.merge(ability_field_updates(row, current))
      result = CreateAbilityEditDraft.call(
        ability: ability,
        proposer: @proposer,
        payload: AbilityPayload.from_hash(merged)
      )
      raise BundleFailed, result.error unless result.ok?

      result.value
    end

    def ability_create_payload(row)
      AbilityPayload.from_hash(
        "name" => row["name"].presence || "Suggested Ability",
        "description" => row["description"].presence || "Describe this ability",
        "department_id" => row["department_id"],
        "milestone_1_description" => ability_milestone_description_for(row, 1),
        "milestone_2_description" => ability_milestone_description_for(row, 2),
        "milestone_3_description" => ability_milestone_description_for(row, 3),
        "milestone_4_description" => ability_milestone_description_for(row, 4),
        "milestone_5_description" => ability_milestone_description_for(row, 5)
      )
    end

    def ability_field_updates(row, current)
      updates = {
        "description" => row["description"].presence || current["description"],
        "name" => row["name"].presence || current["name"]
      }
      (1..5).each do |level|
        key = "milestone_#{level}_description"
        value = ability_milestone_description_for(row, level)
        updates[key] = value if value.present?
      end
      updates.compact
    end

    def ability_milestone_description_for(row, level)
      full = row["milestone_#{level}_description"].presence
      return full if full.present?

      Ability.milestone_description_with_examples(level, ability_milestone_examples_for(row, level))
    end

    def ability_milestone_examples_for(row, level)
      nested = row["milestone_examples"]
      if nested.is_a?(Hash)
        value = nested[level.to_s].presence || nested[level].presence
        return value if value.present?
      end

      row["milestone_#{level}_examples"]
    end

    def find_ability(data)
      if data["ability_id"].present?
        Ability.find_by(id: data["ability_id"], company: @organization)
      elsif data["name"].present?
        Ability.unarchived.where(company: @organization)
               .find_by("LOWER(name) = ?", data["name"].to_s.downcase)
      end
    end

    def redirect_for(proposal)
      return Rails.application.routes.url_helpers.organization_maap_ability_creates_path(@organization) if proposal.nil?

      if proposal.ability_create?
        Rails.application.routes.url_helpers.organization_maap_ability_create_path(@organization, proposal)
      elsif proposal.edit_kind? && proposal.proposable_type == "Ability"
        Rails.application.routes.url_helpers.organization_ability_maap_proposal_path(
          @organization, proposal.proposable, proposal
        )
      else
        Rails.application.routes.url_helpers.organization_maap_ability_creates_path(@organization)
      end
    end
  end
end
