# frozen_string_literal: true

module MaapProposals
  # Spawns Assignment create/edit drafts (+ nested Ability drafts) from MAAP Suggestion chat.
  class CreateAssignmentSuggestionBundle
    def self.call(organization:, proposer:, bundle:)
      new(organization: organization, proposer: proposer, bundle: bundle).call
    end

    def initialize(organization:, proposer:, bundle:)
      @organization = organization
      @proposer = proposer
      @bundle = (bundle || {}).deep_stringify_keys
    end

    def call
      assignments = Array(@bundle["assignments"])
      return Result.err("bundle.assignments must include at least one assignment") if assignments.empty?

      created = []
      primary = nil

      ApplicationRecord.transaction do
        assignments.each do |raw|
          next unless raw.is_a?(Hash)

          row = raw.deep_stringify_keys
          proposal = upsert_assignment!(row, created)
          primary ||= proposal

          Array(row["abilities"]).each do |ability_raw|
            next unless ability_raw.is_a?(Hash)

            ensure_ability!(ability_raw.deep_stringify_keys, proposal, created)
          end
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

    def upsert_assignment!(row, created)
      mode = row["mode"].to_s
      if mode == "edit" || mode == "existing"
        assignment = find_assignment(row)
        raise BundleFailed, "Could not find assignment #{row['title'] || row['path']}" if assignment.nil?
        return nil if mode == "existing"

        proposal = create_assignment_edit!(assignment, row)
        created << proposal
        proposal
      else
        proposal = create_assignment_create!(row)
        created << proposal
        proposal
      end
    end

    def create_assignment_create!(row)
      payload = AssignmentPayload.from_hash(
        "title" => row["title"].presence || "Suggested Assignment",
        "tagline" => row["tagline"],
        "required_activities" => row["required_activities"],
        "handbook" => row["handbook"],
        "department_id" => row["department_id"],
        "outcomes" => Array(row["outcomes"]).map { |o|
          o.is_a?(Hash) ? o : { "description" => o.to_s, "outcome_type" => "quantitative" }
        },
        "ability_milestones" => []
      )
      result = CreateAssignmentCreateDraft.call(
        organization: @organization,
        proposer: @proposer,
        payload: payload
      )
      raise BundleFailed, result.error unless result.ok?

      result.value
    end

    def create_assignment_edit!(assignment, row)
      current = AssignmentPayload.from_assignment(assignment).to_h
      merged = current.merge(
        {
          "title" => row["title"].presence || current["title"],
          "tagline" => row["tagline"].presence || current["tagline"],
          "required_activities" => row["required_activities"].presence || current["required_activities"],
          "handbook" => row["handbook"].presence || current["handbook"]
        }.compact
      )
      if row.key?("outcomes")
        merged["outcomes"] = Array(row["outcomes"]).map { |o|
          o.is_a?(Hash) ? o : { "description" => o.to_s, "outcome_type" => "quantitative" }
        }
      end

      result = CreateAssignmentEditDraft.call(
        assignment: assignment,
        proposer: @proposer,
        payload: AssignmentPayload.from_hash(merged)
      )
      raise BundleFailed, result.error unless result.ok?

      result.value
    end

    def ensure_ability!(row, assignment_proposal, created)
      mode = row["mode"].to_s
      if mode == "existing" || mode == "edit"
        ability = find_ability(row)
        return if ability.nil?

        if mode == "edit"
          proposal = create_ability_edit!(ability, row)
          created << proposal
          link_ability!(assignment_proposal, proposal)
        end

        attach_ability_milestone!(assignment_proposal, ability.id, row["milestone_level"]) if assignment_proposal
        return
      end

      result = CreateAbilityCreateDraft.call(
        organization: @organization,
        proposer: @proposer,
        payload: ability_create_payload(row)
      )
      raise BundleFailed, result.error unless result.ok?

      created << result.value
      link_ability!(assignment_proposal, result.value)
      return unless assignment_proposal

      pending = Array(assignment_proposal.proposed_payload["pending_ability_milestones"])
      pending << {
        "ability_proposal_id" => result.value.id,
        "milestone_level" => (row["milestone_level"].presence || 3).to_i
      }
      assignment_proposal.update!(
        proposed_payload: assignment_proposal.proposed_payload.merge("pending_ability_milestones" => pending)
      )
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

    def attach_ability_milestone!(assignment_proposal, ability_id, milestone_level)
      level = (milestone_level.presence || 3).to_i
      milestones = Array(assignment_proposal.proposed_payload["ability_milestones"])
      milestones << { "ability_id" => ability_id, "milestone_level" => level }
      assignment_proposal.update!(
        proposed_payload: assignment_proposal.proposed_payload.merge("ability_milestones" => milestones)
      )
    end

    def link_ability!(assignment_proposal, ability_proposal)
      return if assignment_proposal.nil? || ability_proposal.nil?

      assignment_proposal.link_child!(ability_proposal, role: "ability")
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

    def find_assignment(data)
      if data["assignment_id"].present?
        Assignment.find_by(id: data["assignment_id"], company: @organization)
      elsif data["title"].present?
        Assignment.unarchived.where(company: @organization)
                  .find_by("LOWER(title) = ?", data["title"].to_s.downcase)
      end
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
      return organization_maap_path if proposal.nil?

      if proposal.assignment_create?
        Rails.application.routes.url_helpers.organization_maap_assignment_create_path(@organization, proposal)
      elsif proposal.edit_kind? && proposal.proposable_type == "Assignment"
        Rails.application.routes.url_helpers.organization_assignment_maap_proposal_path(
          @organization, proposal.proposable, proposal
        )
      else
        organization_maap_path
      end
    end

    def organization_maap_path
      Rails.application.routes.url_helpers.organization_maap_assignment_creates_path(@organization)
    end
  end
end
