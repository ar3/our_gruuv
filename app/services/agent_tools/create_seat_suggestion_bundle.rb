# frozen_string_literal: true

module AgentTools
  # Confirmed write tool: spawn Seat collective proposal + linked child drafts.
  class CreateSeatSuggestionBundle < Base
    def call(context:, bundle: nil, **_ignored)
      context.authorize!(MaapProposal, :create?)

      raw = bundle.is_a?(Hash) ? bundle.deep_stringify_keys : {}
      normalized = normalize_bundle(context, raw)
      result = MaapProposals::CreateSeatSuggestionBundle.call(
        organization: company_for(context),
        proposer: context.company_teammate,
        bundle: normalized
      )
      return err(Array(result.error).join(", "), code: "validation_failed") unless result.ok?

      data = result.value
      ok(
        {
          seat_proposal_id: data[:seat_proposal].id,
          proposal_ids: Array(data[:proposals]).map(&:id),
          redirect_path: data[:redirect_path]
        }
      )
    end

    private

    def normalize_bundle(context, raw)
      title = (raw["title"].is_a?(Hash) ? raw["title"] : {}).dup
      if title["path"].present? || title["title_path"].present?
        found = RecordPaths.resolve_title(
          context,
          path: title["path"],
          title_path: title["title_path"],
          title_id: title["title_id"]
        )
        if found
          title["mode"] = "existing"
          title["title_id"] = found.id
        end
      end

      team = (raw["team"].is_a?(Hash) ? raw["team"] : {}).dup
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
            a["mode"] = a["mode"].presence || "existing"
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
              ab["mode"] = ab["mode"].presence || "existing"
              ab["ability_id"] = found.id
            end
          end
          ab
        end
        a
      end

      raw.merge(
        "title" => title,
        "team" => team,
        "assignments" => assignments
      )
    end

    def company_for(context)
      context.organization
    end
  end
end
