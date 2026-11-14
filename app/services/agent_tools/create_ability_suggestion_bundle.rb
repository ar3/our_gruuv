# frozen_string_literal: true

module AgentTools
  # Confirmed write tool: Ability draft proposals from MAAP Suggestion chat.
  class CreateAbilitySuggestionBundle < Base
    def call(context:, bundle: nil, **_ignored)
      context.authorize!(MaapProposal, :create?)

      raw = bundle.is_a?(Hash) ? bundle.deep_stringify_keys : {}
      normalized = normalize_bundle(context, raw)
      result = MaapProposals::CreateAbilitySuggestionBundle.call(
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
      abilities = Array(raw["abilities"]).map do |row|
        next row unless row.is_a?(Hash)

        ab = row.deep_stringify_keys
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

      raw.merge("abilities" => abilities)
    end
  end
end
