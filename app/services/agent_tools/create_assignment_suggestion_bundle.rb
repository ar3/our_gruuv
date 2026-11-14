# frozen_string_literal: true

module AgentTools
  # Confirmed write tool: Assignment (+ Ability) draft proposals from MAAP Suggestion chat.
  class CreateAssignmentSuggestionBundle < Base
    def call(context:, bundle: nil, **_ignored)
      context.authorize!(MaapProposal, :create?)

      raw = bundle.is_a?(Hash) ? bundle.deep_stringify_keys : {}
      normalized = normalize_bundle(context, raw)
      result = MaapProposals::CreateAssignmentSuggestionBundle.call(
        organization: context.organization,
        proposer: context.company_teammate,
        bundle: normalized
      )
      return err(Array(result.error).join(", "), code: "validation_failed") unless result.ok?

      data = result.value
      ok(
        {
          primary_proposal_id: data[:primary_proposal]&.id,
          proposal_ids: Array(data[:proposals]).map(&:id),
          redirect_path: data[:redirect_path]
        }
      )
    end

    private

    def normalize_bundle(context, raw)
      assignments = Array(raw["assignments"]).map do |row|
        next row unless row.is_a?(Hash)

        a = row.deep_stringify_keys
        if a["path"].present? || a["assignment_path"].present?
          found = RecordPaths.resolve_assignment(
            context,
            path: a["path"],
            assignment_path: a["assignment_path"],
            assignment_id: a["assignment_id"]
          )
          if found
            a["mode"] = a["mode"].presence || "edit"
            a["assignment_id"] = found.id
          end
        end
        a["abilities"] = Array(a["abilities"]).map do |ability_row|
          next ability_row unless ability_row.is_a?(Hash)

          ab = ability_row.deep_stringify_keys
          if ab["path"].present? || ab["ability_path"].present?
            found = RecordPaths.resolve_ability(
              context,
              path: ab["path"],
              ability_path: ab["ability_path"],
              ability_id: ab["ability_id"]
            )
            if found
              ab["mode"] = ab["mode"].presence || "edit"
              ab["ability_id"] = found.id
            end
          end
          ab
        end
        a
      end

      raw.merge("assignments" => assignments)
    end
  end
end
