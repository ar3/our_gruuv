# frozen_string_literal: true

module AgentTools
  # Non-archived abilities visible via AbilityPolicy::Scope + show?.
  class ListAbilities < Base
    DEFAULT_LIMIT = 25

    def call(context:, query: nil, limit: DEFAULT_LIMIT, detail: Detail::DEFAULT, **_ignored)
      context.authorize!(context.organization, :show?)
      detail_level = Detail.normalize(detail)

      company = context.organization.root_company || context.organization
      relation = context.policy_scope(Ability).unarchived.where(company_id: company.id).ordered

      abilities = relation.limit(200).to_a
      needle = query.to_s.strip.downcase
      if needle.present?
        abilities = abilities.select { |ability| ability_matches?(ability, needle) }
      end

      visible = abilities.select { |ability|
        Pundit.policy(context.pundit_user, ability).show?
      }.first(limit.to_i.clamp(1, 50))

      ok(
        abilities: visible.map { |a| MaapSerializers.ability(context, a, detail: detail_level) },
        count: visible.size,
        detail: detail_level
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    rescue ArgumentError => e
      err(e.message, code: "validation_failed")
    end

    private

    def ability_matches?(ability, needle)
      texts = [
        ability.name,
        ability.description,
        ability.milestone_1_description,
        ability.milestone_2_description,
        ability.milestone_3_description,
        ability.milestone_4_description,
        ability.milestone_5_description
      ]
      texts.compact.any? { |text| text.to_s.downcase.include?(needle) }
    end
  end
end
