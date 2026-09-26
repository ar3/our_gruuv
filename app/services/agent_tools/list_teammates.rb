# frozen_string_literal: true

module AgentTools
  # Directory list via CompanyTeammatesQuery + per-row CompanyTeammatePolicy#show?.
  # Does not use CompanyTeammatePolicy::Scope.
  class ListTeammates < Base
    DEFAULT_LIMIT = ListPagination::DEFAULT_LIMIT

    def call(context:, query: nil, limit: DEFAULT_LIMIT, offset: 0, **_ignored)
      context.authorize!(context.organization, :show?)

      relation = CompanyTeammatesQuery.new(
        context.organization,
        {},
        current_person: context.person
      ).call.includes(:person)

      teammates, = ListPagination.scan_relation(relation)
      needle = query.to_s.strip.downcase
      if needle.present?
        teammates = teammates.select do |teammate|
          name = teammate.person&.display_name.to_s.downcase
          email = teammate.person&.email.to_s.downcase
          name.include?(needle) || email.include?(needle)
        end
      end

      visible = teammates.select do |teammate|
        Pundit.policy(context.pundit_user, teammate).show?
      end
      page = ListPagination.slice(visible, limit: limit, offset: offset)

      ok(
        { teammates: page[:items].map { |t| serialize(context, t) } }.merge(page[:meta])
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    end

    private

    def serialize(context, teammate)
      {
        name: teammate.person&.display_name,
        email: teammate.person&.email,
        path: RecordPaths.teammate_path(context, teammate)
      }
    end
  end
end
