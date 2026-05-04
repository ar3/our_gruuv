# frozen_string_literal: true

module AbilitiesHrReview
  # Builds preview_actions hash for BulkSyncEvent::UploadAbilitiesHrReview.
  class BuildPreview
    def self.call(file_content:, organization:)
      new(file_content: file_content, organization: organization).call
    end

    def initialize(file_content:, organization:)
      @file_content = file_content
      @organization = organization
    end

    def call
      parser = CsvBlockParser.new(@file_content)
      unless parser.parse
        return(
          {
            ok: false,
            preview_actions: {
              'rows' => [],
              'parse_errors' => parser.errors
            },
            errors: parser.errors
          }
        )
      end

      rows = parser.ability_rows.map { |raw| build_row(raw) }

      { ok: true, preview_actions: { 'rows' => rows, 'version' => 1 }, errors: [] }
    end

    private

    def build_row(raw)
      id = SecureRandom.hex(6)
      desc_norm = MarkdownNormalizer.call(raw['description_raw'])
      milestones_norm = (1..5).each_with_object({}) do |n, h|
        key = "milestone_#{n}_raw"
        h["milestone_#{n}_normalized"] = MarkdownNormalizer.call(raw[key])
      end

      resolved = AssignmentResolver.call(organization: @organization, title: raw['assignment_raw'].to_s)
      assignment = resolved['assignment_id'] ? Assignment.find_by(id: resolved['assignment_id']) : nil

      join_seed = JoinMilestoneSeed.call(
        assignment: assignment,
        ability_milestone_cell: raw['ability_milestone_raw']
      )

      match = ability_match_for(raw['ability_name'].to_s.strip, assignment)

      {
        'id' => id,
        'state' => 'pending',
        'enrichment_status' => 'pending',
        'source_csv_row' => raw['source_csv_row'],
        'assignment_raw' => raw['assignment_raw'],
        'resolved_assignment_id' => resolved['assignment_id'],
        'assignment_match_kind' => resolved['match_kind'],
        'assignment_alternatives' => resolved['alternatives'],
        'ability_name' => raw['ability_name'],
        'form_ability_name' => match['form_ability_name'],
        'ability_intent' => match['ability_intent'],
        'matched_ability_id' => match['matched_ability_id'],
        'ability_match_kind' => match['ability_match_kind'],
        'ability_alternatives' => match['ability_alternatives'],
        'default_department_label' => match['default_department_label'],
        'description' => {
          'raw' => raw['description_raw'],
          'normalized' => desc_norm,
          'proposed' => nil
        }.stringify_keys,
        'milestones' => (1..5).each_with_object({}) do |n, h|
          h[n.to_s] = {
            'raw' => raw["milestone_#{n}_raw"],
            'normalized' => milestones_norm["milestone_#{n}_normalized"],
            'proposed' => nil
          }.stringify_keys
        end.stringify_keys,
        'join_milestone' => {
          'level' => join_seed['level'],
          'proposed_level' => join_seed['proposed_level'],
          'rationale' => join_seed['rationale'],
          'csv_ability_milestone_raw' => raw['ability_milestone_raw']
        }.stringify_keys,
        'applied_ability_id' => nil,
        'apply_error' => nil
      }.stringify_keys
    end

    # Exact → flexible → full-text search on Ability#name (see AbilityResolver).
    # form_ability_name: canonical DB name when matched (for the text field); otherwise the CSV string.
    def ability_match_for(name_stripped, assignment)
      if name_stripped.blank?
        return {
          'ability_intent' => 'create',
          'matched_ability_id' => nil,
          'ability_match_kind' => 'none',
          'ability_alternatives' => [],
          'default_department_label' => department_label(assignment&.department),
          'form_ability_name' => name_stripped
        }
      end

      ares = AbilityResolver.call(organization: @organization, name: name_stripped)
      if ares['ability_id'].present?
        matched = Ability.find_by(id: ares['ability_id'], company_id: @organization.id)
        {
          'ability_intent' => 'update',
          'matched_ability_id' => ares['ability_id'],
          'ability_match_kind' => ares['match_kind'],
          'ability_alternatives' => ares['alternatives'],
          'default_department_label' => department_label(matched&.department),
          'form_ability_name' => ares['canonical_name'] || name_stripped
        }
      else
        {
          'ability_intent' => 'create',
          'matched_ability_id' => nil,
          'ability_match_kind' => 'none',
          'ability_alternatives' => [],
          'default_department_label' => department_label(assignment&.department),
          'form_ability_name' => name_stripped
        }
      end
    end

    def department_label(dept)
      return 'None' if dept.blank?

      dept.respond_to?(:display_name) ? dept.display_name : dept.name.to_s
    end
  end
end
