# frozen_string_literal: true

module AgentTools
  # Non-archived assignments visible via AssignmentPolicy::Scope + show?.
  class ListAssignments < Base
    DEFAULT_LIMIT = 25

    def call(context:, query: nil, limit: DEFAULT_LIMIT, detail: Detail::DEFAULT, **_ignored)
      context.authorize!(context.organization, :show?)
      detail_level = Detail.normalize(detail)

      company = context.organization.root_company || context.organization
      relation = context.policy_scope(Assignment).unarchived.where(company: company).ordered
      relation = relation.includes(:assignment_outcomes) if Detail.expensive?(detail_level)

      assignments = relation.limit(200).to_a
      needle = query.to_s.strip.downcase
      if needle.present?
        assignments = assignments.select { |assignment| assignment_matches?(assignment, needle) }
      end

      visible = assignments.select { |assignment|
        Pundit.policy(context.pundit_user, assignment).show?
      }.first(limit.to_i.clamp(1, 50))

      ok(
        assignments: visible.map { |a| MaapSerializers.assignment(context, a, detail: detail_level) },
        count: visible.size,
        detail: detail_level
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    rescue ArgumentError => e
      err(e.message, code: "validation_failed")
    end

    private

    def assignment_matches?(assignment, needle)
      [
        assignment.title,
        assignment.tagline,
        assignment.required_activities,
        assignment.handbook
      ].compact.any? { |text| text.to_s.downcase.include?(needle) }
    end
  end
end
