# frozen_string_literal: true

module AbilitiesHrReview
  # Groups parsed CSV rows into ability_groups + deduped association_rows.
  class BuildGroups
    def self.call(parsed_rows:, organization:)
      new(parsed_rows: parsed_rows, organization: organization).call
    end

    def initialize(parsed_rows:, organization:)
      @parsed_rows = parsed_rows
      @organization = organization
    end

    def call
      ability_groups = []
      association_rows = []
      buckets = {}

      @parsed_rows.each do |row|
        if row['invalid'].present?
          ability_groups << build_invalid_group(row)
          next
        end

        key = group_key(row)
        buckets[key] ||= []
        buckets[key] << row
      end

      buckets.each_value do |member_rows|
        group = build_ability_group(member_rows)
        ability_groups << group
        association_rows.concat(build_association_rows(group, member_rows))
      end

      { 'ability_groups' => ability_groups, 'association_rows' => association_rows }
    end

    private

    def group_key(row)
      [
        row['name_key'],
        row['content_fingerprint']
      ]
    end

    def build_invalid_group(row)
      {
        'id' => SecureRandom.hex(6),
        'state' => 'invalid',
        'invalid_reason' => row['invalid_reason'],
        'enrichment_status' => 'skipped',
        'ability_name' => row['ability_name'].to_s.presence || '(unnamed)',
        'form_ability_name' => row['ability_name'].to_s,
        'matched_ability_id' => nil,
        'ability_match_kind' => 'none',
        'match_candidates' => [],
        'description' => row['description'],
        'milestones' => row['milestones'],
        'default_department_id' => nil,
        'default_department_label' => 'None',
        'file_row_count' => 1,
        'file_assignment_count' => 0,
        'file_assignment_titles' => [],
        'existing_associations' => [],
        'applied_ability_id' => nil,
        'ability_action' => nil,
        'apply_error' => nil,
        'source_csv_rows' => [row['source_csv_row']].compact
      }.stringify_keys
    end

    def build_ability_group(member_rows)
      lead = member_rows.first
      match = lead['ability_match']
      assignment_titles = member_rows.map { |r| r['assignment_raw'].to_s.strip }.reject(&:blank?).uniq

      {
        'id' => SecureRandom.hex(6),
        'state' => 'pending',
        'enrichment_status' => 'pending',
        'ability_name' => lead['ability_name'],
        'form_ability_name' => match['form_ability_name'],
        'matched_ability_id' => match['matched_ability_id'],
        'ability_match_kind' => match['ability_match_kind'],
        'match_candidates' => Array(match['match_candidates']),
        'description' => lead['description'],
        'milestones' => lead['milestones'],
        'default_department_id' => match['default_department_id'],
        'default_department_label' => match['default_department_label'],
        'file_row_count' => member_rows.size,
        'file_assignment_count' => assignment_titles.size,
        'file_assignment_titles' => assignment_titles,
        'existing_associations' => existing_associations_for(match['matched_ability_id']),
        'applied_ability_id' => nil,
        'ability_action' => nil,
        'apply_error' => nil,
        'source_csv_rows' => member_rows.map { |r| r['source_csv_row'] }.compact
      }.stringify_keys
    end

    def build_association_rows(group, member_rows)
      seen = {}
      rows = []

      member_rows.each do |row|
        assignment_key = association_dedupe_key(row)
        dedupe = [group['id'], assignment_key]
        next if seen[dedupe]

        seen[dedupe] = true
        rows << {
          'id' => SecureRandom.hex(6),
          'state' => 'pending',
          'ability_group_id' => group['id'],
          'assignment_raw' => row['assignment_raw'],
          'resolved_assignment_id' => row['resolved_assignment_id'],
          'assignment_match_kind' => row['assignment_match_kind'],
          'assignment_alternatives' => row['assignment_alternatives'],
          'join_milestone' => row['join_milestone'],
          'source_csv_row' => row['source_csv_row'],
          'skipped_reason' => nil,
          'apply_error' => nil
        }.stringify_keys
      end

      rows
    end

    def association_dedupe_key(row)
      if row['resolved_assignment_id'].present?
        "id:#{row['resolved_assignment_id']}"
      else
        "raw:#{row['assignment_raw'].to_s.strip.downcase}"
      end
    end

    def existing_associations_for(ability_id)
      ExistingAssociations.list(organization: @organization, ability_id: ability_id)
    end
  end
end
