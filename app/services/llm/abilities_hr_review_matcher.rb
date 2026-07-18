# frozen_string_literal: true

module Llm
  # Finds top similar existing abilities (name, description, milestones) via Bedrock.
  class AbilitiesHrReviewMatcher
    MAX_CANDIDATES = 3
    MAX_POOL = 40
    DEFAULT_MATCH_CONFIDENCE_THRESHOLD = 90

    def self.apply_to_group(group, organization:)
      new(group: group, organization: organization).apply_to_group
    end

    def initialize(group:, organization:)
      @group = group.deep_stringify_keys
      @organization = organization
    end

    def apply_to_group
      return @group if @group['ability_match_kind'].to_s == 'exact_insensitive'
      return @group if @group['state'].to_s == 'invalid'

      candidates = find_candidates
      merge_match_results(candidates)
    end

    private

    def find_candidates
      return [] unless bedrock_configured?

      pool = candidate_pool
      return [] if pool.empty?

      model_id = ENV.fetch('ABILITIES_HR_REVIEW_BEDROCK_MODEL_ID') { Llm::TranscriptMomentsExtractor.default_model_id }
      llm = Llm::Client.call(
        purpose: 'abilities_hr_match',
        model_id: model_id,
        system_instructions: system_instructions,
        user_prompt: user_prompt(pool),
        organization_id: @organization.id
      )
      parse_matches(llm.content.to_s, pool)
    rescue StandardError => e
      Rails.logger.warn("AbilitiesHrReviewMatcher: #{e.class}: #{e.message}")
      []
    end

    def merge_match_results(candidates)
      out = @group.dup
      out['match_candidates'] = candidates.first(MAX_CANDIDATES)

      top = candidates.first
      out['ability_match_kind'] = candidates.any? ? 'ai' : 'none'

      if top && top['confidence'].to_i >= DEFAULT_MATCH_CONFIDENCE_THRESHOLD
        ability = Ability.find_by(id: top['ability_id'], company_id: @organization.id)
        out['matched_ability_id'] = top['ability_id']
        out['form_ability_name'] = ability&.name || out['form_ability_name']
        if ability
          dept = ability.department
          out['default_department_id'] = dept&.id
          out['default_department_label'] = dept_label(dept)
          out['existing_associations'] = AbilitiesHrReview::ExistingAssociations.list(
            organization: @organization,
            ability_id: ability.id
          )
        end
      elsif candidates.empty?
        out['matched_ability_id'] = nil
        out['match_candidates'] = []
      else
        out['matched_ability_id'] = nil
      end

      out
    end

    def candidate_pool
      scope = Ability.unarchived.where(company_id: @organization.id)
      query = import_text_for_search
      abilities =
        if scope.count > MAX_POOL && query.present?
          Ability.search_by_full_text(query).where(company_id: @organization.id).limit(MAX_POOL).to_a
        else
          scope.order(:name).limit(MAX_POOL).to_a
        end

      abilities.map { |a| ability_payload(a) }
    end

    def ability_payload(ability)
      {
        'id' => ability.id,
        'name' => ability.name,
        'description' => ability.description.to_s.truncate(800),
        'milestones' => (1..5).filter_map do |n|
          text = ability.send("milestone_#{n}_description").to_s.strip
          next if text.blank?

          "M#{n}: #{text.truncate(300)}"
        end.join(' | ')
      }
    end

    def import_text_for_search
      parts = [@group['ability_name'].to_s]
      desc = (@group['description'] || {}).stringify_keys
      parts << desc['normalized'].presence || desc['raw'].presence
      milestones = (@group['milestones'] || {}).stringify_keys
      (1..5).each do |n|
        h = milestones[n.to_s]
        next unless h.is_a?(Hash)

        h = h.stringify_keys
        parts << h['normalized'].presence || h['raw'].presence
      end
      parts.compact.join(' ').squish
    end

    def import_payload
      desc = (@group['description'] || {}).stringify_keys
      description = desc['proposed'].presence || desc['normalized'].presence || desc['raw'].presence || ''
      milestones = (@group['milestones'] || {}).stringify_keys
      milestone_lines = (1..5).filter_map do |n|
        h = milestones[n.to_s]
        next unless h.is_a?(Hash)

        h = h.stringify_keys
        text = h['proposed'].presence || h['normalized'].presence || h['raw'].presence
        next if text.blank?

        "Milestone #{n}: #{text.to_s.truncate(400)}"
      end

      {
        'name' => @group['ability_name'].to_s,
        'description' => description.to_s.truncate(1200),
        'milestones' => milestone_lines
      }
    end

    def system_instructions
      <<~TXT.squish
        You compare an imported HR ability to existing abilities in the same company.
        Return ONLY valid JSON:
        {"matches":[{"ability_id":123,"confidence":85}]}
        Rules:
        - Include at most #{MAX_CANDIDATES} matches, sorted by confidence descending.
        - confidence is an integer 0-100 meaning how likely the existing ability is the same skill as the import.
        - Consider similar names AND very similar descriptions and milestone text.
        - Only use ability_id values from the provided catalog.
        - If nothing is reasonably similar, return {"matches":[]}.
      TXT
    end

    def user_prompt(pool)
      import = import_payload
      catalog = pool.map do |a|
        "- id=#{a['id']} name=#{a['name'].inspect} description=#{a['description'].inspect} milestones=#{a['milestones'].inspect}"
      end.join("\n")

      <<~TXT
        Imported ability:
        name: #{import['name'].inspect}
        description: #{import['description'].inspect}
        #{import['milestones'].map { |l| "  #{l}" }.join("\n")}

        Existing abilities catalog:
        #{catalog}
      TXT
    end

    def parse_matches(raw, pool)
      by_id = pool.index_by { |a| a['id'] }
      json = extract_json_object(raw)
      data = JSON.parse(json)
      Array(data['matches']).filter_map do |h|
        next unless h.is_a?(Hash)

        id = h['ability_id'].to_i
        next unless id.positive? && by_id[id]

        confidence = h['confidence'].to_i.clamp(0, 100)
        next if confidence.zero?

        {
          'ability_id' => id,
          'name' => by_id[id]['name'],
          'confidence' => confidence,
          'match_kind' => 'ai'
        }
      end.sort_by { |c| -c['confidence'] }.first(MAX_CANDIDATES)
    rescue JSON::ParserError => e
      Rails.logger.warn("AbilitiesHrReviewMatcher JSON parse: #{e.message}")
      []
    end

    def extract_json_object(raw)
      text = raw.to_s.strip
      if (m = text.match(/\{.*\}/m))
        m[0]
      else
        '{}'
      end
    end

    def dept_label(dept)
      return 'None' if dept.blank?

      dept.respond_to?(:display_name) ? dept.display_name : dept.name.to_s
    end

    def bedrock_configured?
      cfg = RubyLLM.config
      cfg.bedrock_api_key.present? && cfg.bedrock_secret_key.present? && cfg.bedrock_region.present?
    end
  end
end
