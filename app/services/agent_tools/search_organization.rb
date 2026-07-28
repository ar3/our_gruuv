# frozen_string_literal: true

module AgentTools
  # Org search via GlobalSearchQuery; same surface as Organizations::SearchController.
  class SearchOrganization < Base
    def call(context:, query:, impersonating_teammate: nil, **_ignored)
      context.authorize!(context.organization, :view_search?)

      q = query.to_s.strip
      return err("query is required") if q.blank?

      results = GlobalSearchQuery.new(
        query: q,
        current_organization: context.organization,
        current_teammate: context.company_teammate,
        impersonating_teammate: impersonating_teammate
      ).call

      ok(
        query: q,
        total_count: results[:total_count],
        people: summarize_people(context, results[:people]),
        go_to: Array(results[:go_to]).first(10).map { |e| { label: e.label, path: e.path, section: e.section_label } },
        assignments: Array(results[:assignments]).first(10).map { |a|
          { title: a.title, path: RecordPaths.assignment_path(context, a) }
        },
        abilities: Array(results[:abilities]).first(10).map { |a|
          { name: a.name, path: RecordPaths.ability_path(context, a) }
        },
        titles: Array(results[:titles]).first(10).map { |t|
          { title: t.external_title, path: RecordPaths.title_path(context, t) }
        },
        observations: Array(results[:observations]).first(10).map { |o|
          { story_preview: o.story.to_s.truncate(120), path: RecordPaths.observation_path(context, o) }
        }
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message)
    end

    private

    def summarize_people(context, people)
      Array(people).first(10).filter_map do |person|
        teammate = person.teammates.find_by(organization: context.organization)
        next if teammate.nil?

        {
          name: person.display_name,
          email: person.email,
          path: RecordPaths.teammate_path(context, teammate)
        }
      end
    end
  end
end
