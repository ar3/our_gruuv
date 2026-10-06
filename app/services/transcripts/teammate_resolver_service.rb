# frozen_string_literal: true

module Transcripts
  class TeammateResolverService
    MAX_ALTERNATES = 3

    def self.call(organization:, label:, teammates: nil, parent: nil)
      new(organization: organization, label: label, teammates: teammates, parent: parent).call
    end

    def initialize(organization:, label:, teammates:, parent: nil)
      @organization = organization
      @label = label.to_s.strip
      @teammates = teammates
      @parent = parent
    end

    # Returns { company_teammate_id:, unknown:, alternates: [{ company_teammate_id, name }] }
    def call
      blank_result = { company_teammate_id: nil, unknown: true, alternates: [] }
      return blank_result if @label.blank?

      teammates = @teammates || CompanyTeammate.employed.where(organization: @organization).includes(:person).to_a
      return blank_result if teammates.empty?

      ranked = ranked_candidates(teammates)
      if ranked.any?
        primary = ranked.first[:teammate]
        sure = ranked.one?
        alternates = ranked.drop(1).first(MAX_ALTERNATES).map { |row| alternate_hash(row[:teammate]) }
        return {
          company_teammate_id: primary.id,
          unknown: !sure,
          alternates: sure ? [] : alternates
        }
      end

      llm_match(teammates) || blank_result
    end

    private

    def ranked_candidates(teammates)
      needle = normalize(@label)
      teammates.filter_map do |teammate|
        score = score_for(teammate.person, needle)
        next if score <= 0

        { teammate: teammate, score: score }
      end.sort_by { |row| [-row[:score], row[:teammate].id] }
    end

    def score_for(person, needle)
      return 0 unless person

      display = normalize(person.display_name)
      casual = normalize(person.casual_name)
      first = normalize(person.first_name)
      preferred = normalize(person.preferred_name)
      last = normalize(person.last_name)

      return 100 if display.present? && display == needle
      return 95 if casual.present? && casual == needle
      return 92 if first.present? && last.present? && needle == "#{first} #{last}"

      tokens = [first, preferred, last].compact_blank.uniq
      hits = tokens.count { |token| token.length >= 2 && needle.match?(/(?:\A|\s)#{Regexp.escape(token)}(?:\s|\z)/) }
      return 80 if hits >= 2
      return 55 if first.present? && needle == first
      return 50 if preferred.present? && needle == preferred
      return 45 if last.present? && needle == last
      return 40 if tokens.any? { |token| token.length >= 3 && needle.include?(token) }

      0
    end

    def normalize(value)
      value.to_s.downcase.gsub(/[^a-z0-9]+/, " ").squish
    end

    def alternate_hash(teammate)
      {
        "company_teammate_id" => teammate.id,
        "name" => teammate.person.display_name.to_s
      }
    end

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

      model_id = ENV.fetch("TRANSCRIPT_BEDROCK_MODEL_ID") { Llm::TranscriptMomentsExtractor.default_model_id }
      llm = Llm::Client.call(
        purpose: "teammate_resolve",
        model_id: model_id,
        system_instructions:
          "You map one transcript speaker label to teammates from a candidate list. " \
          "Return ONLY JSON: {\"company_teammate_id\":<integer or null>,\"unknown\":<true|false>," \
          "\"alternate_ids\":[<integers>]}. " \
          "Set unknown=true when ambiguous. alternate_ids are other plausible matches, max 3, never invent ids.",
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

      ids_by_record = teammates.index_by(&:id)
      primary_id = parsed["company_teammate_id"].presence&.to_i
      primary_id = nil unless ids_by_record.key?(primary_id)
      unknown = ActiveModel::Type::Boolean.new.cast(parsed["unknown"])
      unknown = true if primary_id.blank?

      alternate_ids = Array(parsed["alternate_ids"]).map(&:to_i).uniq
      alternate_ids.delete(primary_id)
      alternates = alternate_ids.filter_map { |id| ids_by_record[id] }.first(MAX_ALTERNATES).map { |tm| alternate_hash(tm) }

      if primary_id.present?
        { company_teammate_id: primary_id, unknown: unknown || alternates.any?, alternates: unknown || alternates.any? ? alternates : [] }
      elsif unknown
        { company_teammate_id: nil, unknown: true, alternates: alternates }
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
