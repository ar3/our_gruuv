# frozen_string_literal: true

module AbilitiesHrReview
  # Builds preview_actions hash for BulkSyncEvent::UploadAbilitiesHrReview (v2).
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
              'ability_groups' => [],
              'association_rows' => [],
              'parse_errors' => parser.errors,
              'parse_warnings' => parser.warnings
            },
            errors: parser.errors
          }
        )
      end

      parsed_rows = parser.ability_rows.map { |raw| build_parsed_row(raw) }
      grouped = BuildGroups.call(parsed_rows: parsed_rows, organization: @organization)

      {
        ok: true,
        preview_actions: grouped.merge(
          'version' => 2,
          'parse_warnings' => parser.warnings
        ),
        errors: []
      }
    end

    private

    def build_parsed_row(raw)
      name_stripped = raw['ability_name'].to_s.strip
      if name_stripped.blank?
        return invalid_parsed_row(raw, 'Ability name is required')
      end

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

      description = {
        'raw' => raw['description_raw'],
        'normalized' => desc_norm,
        'proposed' => nil
      }.stringify_keys
      milestones = (1..5).each_with_object({}) do |n, h|
        h[n.to_s] = {
          'raw' => raw["milestone_#{n}_raw"],
          'normalized' => milestones_norm["milestone_#{n}_normalized"],
          'proposed' => nil
        }.stringify_keys
      end.stringify_keys

      match = ability_match_for(name_stripped, assignment, description: description, milestones: milestones)

      {
        'source_csv_row' => raw['source_csv_row'],
        'assignment_raw' => raw['assignment_raw'],
        'resolved_assignment_id' => resolved['assignment_id'],
        'assignment_match_kind' => resolved['match_kind'],
        'assignment_alternatives' => resolved['alternatives'],
        'ability_name' => name_stripped,
        'name_key' => name_stripped.downcase,
        'content_fingerprint' => ContentFingerprint.call(
          description_normalized: desc_norm,
          milestone_normalized: milestones_norm
        ),
        'ability_match' => match,
        'description' => description,
        'milestones' => milestones,
        'join_milestone' => {
          'level' => join_seed['level'],
          'proposed_level' => join_seed['proposed_level'],
          'rationale' => join_seed['rationale'],
          'csv_ability_milestone_raw' => raw['ability_milestone_raw']
        }.stringify_keys
      }.stringify_keys
    end

    def invalid_parsed_row(raw, reason)
      {
        'invalid' => true,
        'invalid_reason' => reason,
        'source_csv_row' => raw['source_csv_row'],
        'assignment_raw' => raw['assignment_raw'],
        'ability_name' => raw['ability_name'].to_s.strip,
        'description' => {
          'raw' => raw['description_raw'].to_s,
          'normalized' => MarkdownNormalizer.call(raw['description_raw']),
          'proposed' => nil
        }.stringify_keys,
        'milestones' => (1..5).each_with_object({}) do |n, h|
          h[n.to_s] = {
            'raw' => raw["milestone_#{n}_raw"].to_s,
            'normalized' => MarkdownNormalizer.call(raw["milestone_#{n}_raw"]),
            'proposed' => nil
          }.stringify_keys
        end.stringify_keys
      }.stringify_keys
    end

    def ability_match_for(name_stripped, assignment, description:, milestones:)
      ares = AbilityResolver.call(
        organization: @organization,
        name: name_stripped,
        description: description,
        milestones: milestones
      )
      if ares['ability_id'].present?
        matched = Ability.find_by(id: ares['ability_id'], company_id: @organization.id)
        dept = matched&.department
        {
          'matched_ability_id' => ares['ability_id'],
          'ability_match_kind' => ares['match_kind'],
          'match_candidates' => ares['match_candidates'],
          'default_department_id' => dept&.id,
          'default_department_label' => department_label(dept),
          'form_ability_name' => ares['canonical_name'] || name_stripped
        }
      else
        dept = assignment&.department
        {
          'matched_ability_id' => nil,
          'ability_match_kind' => ares['match_kind'],
          'match_candidates' => ares['match_candidates'],
          'default_department_id' => dept&.id,
          'default_department_label' => department_label(dept),
          'form_ability_name' => name_stripped
        }
      end.stringify_keys
    end

    def department_label(dept)
      return 'None' if dept.blank?

      dept.respond_to?(:display_name) ? dept.display_name : dept.name.to_s
    end
  end
end
