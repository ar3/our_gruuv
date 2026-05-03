# frozen_string_literal: true

module Maap
  # Appends a payload section listing markdown `[Label](path)` snippets for abilities, assignments,
  # and positions so MAAP agents can cite entities with working links in Current | Proposed and prose.
  #
  # Call {append_to_sections!} from any +Maap::*PayloadBuilder+ (ability, assignment, position clarity, etc.).
  class EntityLinkReferenceSection
    class << self
      def append_to_sections!(sections, organization:, abilities: [], assignments: [], positions: [])
        body = build_body(
          organization: organization,
          abilities: abilities,
          assignments: assignments,
          positions: positions
        )
        return if body.blank?

        sections << {
          'title' => 'Markdown links for named entities (required when citing these records)',
          'body' => body
        }
      end

      private

      def route_helpers
        Rails.application.routes.url_helpers
      end

      def build_body(organization:, abilities:, assignments:, positions:)
        org = organization
        return '' if org.blank?

        ab = normalize_records(abilities)
        asg = normalize_records(assignments)
        pos = normalize_records(positions)
        return '' if ab.empty? && asg.empty? && pos.empty?

        lines = []
        lines << <<~INTRO.strip
          When you mention any of these MAAP records **by name** — especially in the **Current | Proposed** table —
          paste the **exact** markdown snippet shown on its own line (full `[label](path)` including brackets). That renders as a link to the record’s **show** page in ourgruuv. Do not invent paths.

          Use **only** paths listed here for entities that appear in this catalog. For other names (people, departments), plain text is fine.
        INTRO
        lines << ''

        append_abilities(lines, org, ab)
        append_assignments(lines, org, asg)
        append_positions(lines, org, pos)

        lines.join("\n").strip
      end

      def append_abilities(lines, org, list)
        return if list.blank?

        lines << '**Abilities**'
        list.each do |ability|
          path = route_helpers.organization_ability_path(org, ability)
          lines << "- #{markdown_link(ability.name, path)}"
        end
        lines << ''
      end

      def append_assignments(lines, org, list)
        return if list.blank?

        lines << '**Assignments**'
        list.each do |assignment|
          path = route_helpers.organization_assignment_path(org, assignment)
          lines << "- #{markdown_link(assignment.title, path)}"
        end
        lines << ''
      end

      def append_positions(lines, org, list)
        return if list.blank?

        lines << '**Positions**'
        list.each do |position|
          path = route_helpers.organization_position_path(org, position)
          lines << "- #{markdown_link(position.display_name, path)}"
        end
        lines << ''
      end

      def normalize_records(records)
        Array(records).compact.uniq { |r| [r.class.name, r.id] }.sort_by do |r|
          case r
          when Ability
            r.name.to_s.downcase
          when Assignment
            r.title.to_s.downcase
          when Position
            r.display_name.to_s.downcase
          else
            r.id.to_s
          end
        end
      end

      def markdown_link(label, path)
        escaped = escape_link_label(label)
        "[#{escaped}](#{path})"
      end

      def escape_link_label(str)
        str.to_s.gsub('[', '\\[').gsub(']', '\\]')
      end
    end
  end
end
