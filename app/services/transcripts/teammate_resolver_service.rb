# frozen_string_literal: true

module Transcripts
  class TeammateResolverService
    def self.call(organization:, label:, teammates: nil, parent: nil)
      new(organization: organization, label: label, teammates: teammates, parent: parent).call
    end

    def initialize(organization:, label:, teammates:, parent: nil)
      @organization = organization
      @label = label.to_s.strip
      @teammates = teammates
      @parent = parent
    end

    # Returns { company_teammate_id:, unknown: true/false }
    def call
      return { company_teammate_id: nil, unknown: true } if @label.blank?

      teammates = @teammates || CompanyTeammate.employed.where(organization: @organization).includes(:person).to_a
      return { company_teammate_id: nil, unknown: true } if teammates.empty?

      llm_match = llm_match(teammates)
      return llm_match if llm_match

      normalized = @label.downcase

      exact = teammates.find { |t| t.person.display_name.to_s.downcase == normalized }
      return { company_teammate_id: exact.id, unknown: false } if exact

      casual = teammates.find { |t| t.person.casual_name.to_s.downcase == normalized }
      return { company_teammate_id: casual.id, unknown: false } if casual

      token_hits = teammates.select do |t|
        p = t.person
        [p.first_name, p.preferred_name, p.last_name].compact.any? { |n| n.present? && normalized.include?(n.downcase) }
      end
      return { company_teammate_id: token_hits.first.id, unknown: false } if token_hits.one?
      return { company_teammate_id: nil, unknown: true } if token_hits.many?

      person_ids = teammates.map(&:person_id)
      matches = Person.search_by_full_text(@label).where(id: person_ids).limit(5).to_a
      teammate_by_person = teammates.index_by(&:person_id)
      mapped = matches.filter_map { |person| teammate_by_person[person.id] }
      return { company_teammate_id: mapped.first.id, unknown: false } if mapped.one?

      { company_teammate_id: nil, unknown: true }
    end

    private

    def llm_match(teammates)
      return nil unless bedrock_configured?

      options = teammates.map do |t|
        person = t.person
        {
          id: t.id,
          display_name: person.display_name.to_s,
          casual_name: person.casual_name.to_s,
          first_name: person.first_name.to_s,
          preferred_name: person.preferred_name.to_s,
          last_name: person.last_name.to_s
        }
      end

      model_id = ENV.fetch('TRANSCRIPT_BEDROCK_MODEL_ID') { Llm::TranscriptMomentsExtractor.default_model_id }
      llm = Llm::Client.call(
        purpose: 'teammate_resolve',
        model_id: model_id,
        system_instructions:
          'You map one transcript speaker label to one teammate from a candidate list. ' \
          'Return ONLY JSON: {"company_teammate_id":<integer or null>,"unknown":<true|false>}. ' \
          'Set unknown=true when ambiguous or no confident match. Never invent ids.',
        user_prompt: <<~TXT,
          Transcript label: #{@label}

          Candidate teammates JSON:
          #{options.to_json}
        TXT
        organization_id: @organization.id,
        parent: @parent
      )
      parsed = parse_llm_json(llm.content.to_s)
      return nil unless parsed.is_a?(Hash)

      teammate_id = parsed['company_teammate_id'].presence&.to_i
      unknown = ActiveModel::Type::Boolean.new.cast(parsed['unknown'])
      if teammate_id.present? && teammates.any? { |t| t.id == teammate_id }
        { company_teammate_id: teammate_id, unknown: false }
      elsif unknown
        { company_teammate_id: nil, unknown: true }
      end
    rescue StandardError => e
      Rails.logger.info("TeammateResolverService llm_match fallback: #{e.class}: #{e.message}")
      nil
    end

    def parse_llm_json(raw)
      text = raw.to_s.strip
      return nil if text.blank?

      json_str = text[/\{.*\}/m]
      return nil if json_str.blank?

      JSON.parse(json_str)
    rescue JSON::ParserError
      nil
    end

    def bedrock_configured?
      cfg = RubyLLM.config
      cfg.bedrock_api_key.present? && cfg.bedrock_secret_key.present? && cfg.bedrock_region.present?
    end
  end
end
