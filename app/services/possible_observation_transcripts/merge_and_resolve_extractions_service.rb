# frozen_string_literal: true

module PossibleObservationTranscripts
  # Merges chunk-level raw items, dedupes, resolves speaker/recipient labels to teammate ids.
  class MergeAndResolveExtractionsService
    def self.call(organization:, raw_items_by_chunk:, llm_parent: nil)
      new(organization: organization, raw_items_by_chunk: raw_items_by_chunk, llm_parent: llm_parent).call
    end

    def initialize(organization:, raw_items_by_chunk:, llm_parent: nil)
      @organization = organization
      @raw_items_by_chunk = raw_items_by_chunk
      @llm_parent = llm_parent
    end

    def call
      merged = []
      seen = Set.new
      teammates = CompanyTeammate.employed.where(organization: @organization).includes(:person).to_a
      resolution_cache = {}

      @raw_items_by_chunk.each do |items|
        Array(items).each do |raw|
          key = dedupe_key(raw)
          next if key.blank? || seen.include?(key)

          seen.add(key)
          merged << build_item(raw, teammates: teammates, resolution_cache: resolution_cache)
        end
      end

      merged
    end

    private

    def dedupe_key(raw)
      q = raw['full_quote'].presence || raw['short_quote'].presence || raw['quote']
      q = q.to_s.downcase.gsub(/\s+/, ' ').strip[0, 200]
      sp = raw['speaker_label'].to_s.downcase.strip
      rp = raw['recipient_label'].to_s.downcase.strip
      "#{sp}|#{rp}|#{q}"
    end

    def build_item(raw, teammates:, resolution_cache:)
      id = SecureRandom.uuid
      speaker = resolve_label(raw['speaker_label'], teammates: teammates, resolution_cache: resolution_cache)
      recipient = resolve_label(raw['recipient_label'], teammates: teammates, resolution_cache: resolution_cache)

      {
        'id' => id,
        'kind' => raw['kind'],
        'quote' => raw['quote'].to_s,
        'summary' => raw['summary'].to_s,
        'short_quote' => raw['short_quote'].to_s,
        'full_quote' => raw['full_quote'].to_s,
        'speaker_label' => raw['speaker_label'].to_s,
        'recipient_label' => raw['recipient_label'].to_s,
        'responder_company_teammate_id' => speaker[:company_teammate_id],
        'subject_company_teammate_id' => recipient[:company_teammate_id],
        'observer_unknown' => speaker[:unknown],
        'observee_unknown' => recipient[:unknown],
        'feedback_request_id' => nil,
        'include' => !speaker[:unknown] && !recipient[:unknown]
      }
    end

    def resolve_label(label, teammates:, resolution_cache:)
      key = label.to_s.strip.downcase
      resolution_cache[key] ||= Transcripts::TeammateResolverService.call(
        organization: @organization,
        label: label,
        teammates: teammates,
        parent: @llm_parent
      )
    end
  end
end
