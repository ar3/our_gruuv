# frozen_string_literal: true

module AgentTools
  # Org search via GlobalSearchQuery; same surface as Organizations::SearchController.
  class SearchOrganization < Base
    def call(context:, query:, detail: Detail::DEFAULT, impersonating_teammate: nil, **_ignored)
      context.authorize!(context.organization, :view_search?)
      detail_level = Detail.normalize(detail)

      q = query.to_s.strip
      return err("query is required", code: "validation_failed") if q.blank?

      results = GlobalSearchQuery.new(
        query: q,
        current_organization: context.organization,
        current_teammate: context.company_teammate,
        impersonating_teammate: impersonating_teammate
      ).call

      assignments = Array(results[:assignments]).reject(&:archived?).first(10)
      if Detail.expensive?(detail_level)
        ActiveRecord::Associations::Preloader.new(
          records: assignments,
          associations: :assignment_outcomes
        ).call
      end

      abilities = Array(results[:abilities]).reject(&:archived?).first(10)

      ok(
        query: q,
        detail: detail_level,
        total_count: results[:total_count],
        people: summarize_people(context, results[:people]),
        go_to: Array(results[:go_to]).first(10).map { |e| { label: e.label, path: e.path, section: e.section_label } },
        assignments: assignments.map { |a|
          MaapSerializers.assignment(context, a, detail: detail_level)
        },
        abilities: abilities.map { |a|
          MaapSerializers.ability(context, a, detail: detail_level)
        },
        titles: Array(results[:titles]).first(10).map { |t|
          { title: t.external_title, path: RecordPaths.title_path(context, t) }
        },
        observations: Array(results[:observations]).first(10).map { |o|
          { story_preview: o.story.to_s.truncate(120), path: RecordPaths.observation_path(context, o) }
        }
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    rescue ArgumentError => e
      err(e.message, code: "validation_failed")
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
