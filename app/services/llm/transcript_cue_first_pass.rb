# frozen_string_literal: true

module Llm
  # Fast Bedrock pass: per-cue OGO-worthiness + observer/observee labels and teammate IDs.
  # Batches cues; roster is included so resolution happens in the same call (no per-label resolve).
  # Default: Nova 2 Lite (speed/cost). Override with TRANSCRIPT_FIRST_PASS_BEDROCK_MODEL_ID.
  class TranscriptCueFirstPass
    # Prompt version: <major>.<YYYYMMDD>.<minor> — see docs/RULES/prompt-versioning.md
    # 1.20261031.0 — initial cue worthiness + observer/observee labels
    # 1.20261031.1 — same call maps labels to company_teammate_ids from roster
    # 1.20261031.2 — split multi-shout-out turns into moments[] when observees clearly change
    # 1.20261031.3 — moments use verbatim anchors; excerpts sliced from cue text only
    PROMPT_VERSION = "1.20261031.3"
    BATCH_SIZE = 30
    TEXT_LIMIT = 4_000
    MIN_ANCHOR_CHARS = 12
    NOVA_2_LITE_FOUNDATION_SUFFIX = "amazon.nova-2-lite-v1:0"

    def self.model_id
      ENV.fetch("TRANSCRIPT_FIRST_PASS_BEDROCK_MODEL_ID") { default_model_id }
    end

    def self.default_model_id
      "#{SlackMomentsExtractor.region_prefix}.#{NOVA_2_LITE_FOUNDATION_SUFFIX}"
    end

    def self.prompt_version
      PROMPT_VERSION
    end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(cues:, organization_id:, teammates: nil, triggered_by_teammate_id: nil, parent: nil, model_id: nil)
      @cues = Array(cues)
      @organization_id = organization_id
      @teammates = Array(teammates)
      @triggered_by_teammate_id = triggered_by_teammate_id
      @parent = parent
      @model_id = model_id.presence || self.class.model_id
      @valid_teammate_ids = @teammates.map(&:id).to_set
      @cue_text_by_id = @cues.each_with_object({}) do |cue, memo|
        cue = cue.with_indifferent_access
        memo[cue[:id].to_s] = cue[:text].to_s
      end
    end

    # Returns cue_id => { "moments" => [ {..., "excerpt" => <slice of original cue text>}, ...] }
    def call
      results = {}
      @cues.each_slice(BATCH_SIZE) do |batch|
        results.merge!(run_batch(batch))
      end

      @cues.each do |cue|
        cue = cue.with_indifferent_access
        id = cue[:id].to_s
        next if results[id].present?

        audio = cue[:kind].to_s == "audio_share"
        results[id] = {
          "moments" => [
            fallback_moment(
              cue_text: cue[:text].to_s,
              speaker: cue[:speaker_label].to_s,
              reason: audio ? "audio_share_default_ignore" : "model_omitted_default_ignore"
            )
          ]
        }
      end
      results
    end

    private

    def run_batch(batch)
      payload = batch.map do |cue|
        cue = cue.with_indifferent_access
        {
          "id" => cue[:id],
          "start" => cue[:start],
          "speaker" => cue[:speaker_label],
          "kind" => cue[:kind],
          "text" => cue[:text].to_s.truncate(TEXT_LIMIT)
        }
      end

      system = <<~SYS
        You label meeting transcript cues for an observation product (OurGruuv Observations / OGOs).
        An OGO-worthy moment is celebration (kudos/shout-out) or constructive criticism about a person's work or behavior.
        Ignore: music/lyrics, screen-share audio, logistics, host transitions, values roll-call without praise/critique, pure small talk.

        STAY FAITHFUL TO THE TRANSCRIPT. Never invent, paraphrase, summarize, or borrow wording from another cue.
        Default: one moment per cue.
        Split into multiple moments ONLY when the speaker clearly starts a separate shout-out/critique about a different person or distinct group — e.g. "First, for Kayla…" then later "which is Amy…" / "couple more" / "next".
        Keep joint shout-outs together (Kayla and Nicole praised as a pair = one moment).
        Do NOT split every name mention, pronouns, or restating the same people. Prefer under-splitting over over-splitting.

        For each moment return:
        - anchor: a VERBATIM contiguous substring copied from that cue's text (#{MIN_ANCHOR_CHARS}+ characters) that starts this moment. Must appear in the cue text (same words/punctuation). Do not rewrite.
        - observer_label: who is speaking (usually the cue speaker)
        - observee_labels: who that moment is about (empty if team/none/unclear)
        - observer_company_teammate_id / observee_company_teammate_ids: roster ids; null/[] if unsure. Never invent ids.
        Prefer precision over recall for ogo_worthy.
        Respond with ONLY a JSON object:
        {"cues":[{"id":"cue-1","moments":[{"ogo_worthy":true,"anchor":"First, for, Kayla and Nicole.","observer_label":"...","observee_labels":["Kayla","Nicole"],"observer_company_teammate_id":123,"observee_company_teammate_ids":[456,789],"reason":"short"}]}]}.
      SYS

      user = <<~USER
        Roster JSON (id + names only):
        #{JSON.pretty_generate(roster_payload)}

        Cues JSON:
        #{JSON.pretty_generate(payload)}
      USER

      result = Llm::Client.call(
        purpose: "transcript_cue_first_pass",
        model_id: @model_id,
        system_instructions: system,
        user_prompt: user,
        organization_id: @organization_id,
        triggered_by_teammate_id: @triggered_by_teammate_id,
        parent: @parent,
        prompt_version: PROMPT_VERSION
      )

      parse_response(result.content.to_s)
    rescue StandardError => e
      Rails.logger.error("TranscriptCueFirstPass batch failed: #{e.class} #{e.message}")
      {}
    end

    def roster_payload
      @teammates.map do |tm|
        person = tm.person
        {
          "id" => tm.id,
          "display_name" => person.display_name.to_s,
          "preferred_name" => person.preferred_name.to_s,
          "casual_name" => person.casual_name.to_s,
          "first_name" => person.first_name.to_s,
          "last_name" => person.last_name.to_s
        }
      end
    end

    def parse_response(content)
      json_text = content.to_s[/(\{.*\})/m, 1] || content
      data = JSON.parse(json_text)
      rows = Array(data["cues"])
      rows.each_with_object({}) do |row, memo|
        row = row.stringify_keys
        id = row["id"].to_s
        next if id.blank?

        cue_text = @cue_text_by_id[id].to_s
        moments = bind_moments_to_transcript(cue_text, normalize_moments(row))
        next if moments.empty?

        memo[id] = { "moments" => moments }
      end
    rescue JSON::ParserError
      {}
    end

    def normalize_moments(row)
      raw_moments = Array(row["moments"])
      if raw_moments.empty? && (row.key?("ogo_worthy") || row.key?("observee_labels"))
        raw_moments = [row]
      end

      raw_moments.filter_map do |moment|
        moment = moment.stringify_keys
        {
          "ogo_worthy" => ActiveModel::Type::Boolean.new.cast(moment["ogo_worthy"]),
          "observer_label" => moment["observer_label"].to_s.strip,
          "observee_labels" => Array(moment["observee_labels"]).map { |label| label.to_s.strip }.reject(&:blank?),
          "observer_company_teammate_id" => sanitize_id(moment["observer_company_teammate_id"]),
          "observee_company_teammate_ids" => Array(moment["observee_company_teammate_ids"]).filter_map { |raw| sanitize_id(raw) }.uniq,
          "anchor" => moment["anchor"].presence || moment["excerpt"].to_s.strip,
          "reason" => moment["reason"].to_s.strip
        }
      end
    end

    # Ground every moment in the original cue text. Never keep invented wording.
    def bind_moments_to_transcript(cue_text, moments)
      return [] if cue_text.blank?
      return [fallback_moment(cue_text: cue_text, speaker: "", reason: "empty_moments")] if moments.blank?

      if moments.size == 1
        moment = moments.first
        return [moment.merge("excerpt" => cue_text).except("anchor")]
      end

      located = moments.filter_map do |moment|
        index = anchor_index(cue_text, moment["anchor"])
        next if index.nil?

        { moment: moment, index: index }
      end

      # If split anchors can't be verified, try discourse-marker slices from the cue text.
      if located.size < 2
        marker_segments = Transcripts::SplitDistinctShoutOutsService.split_text(cue_text)
        if marker_segments.size >= 2
          return assign_moments_to_segments(moments, marker_segments)
        end

        primary = moments.find { |moment| moment["ogo_worthy"] } || moments.first
        return [
          primary.merge(
            "excerpt" => cue_text,
            "reason" => [primary["reason"], "split_anchors_unverified"].reject(&:blank?).join("; ")
          ).except("anchor")
        ]
      end

      located = located.sort_by { |row| [row[:index], moments.index(row[:moment]).to_i] }
      located.each_with_index.map do |row, i|
        start_idx = row[:index]
        end_idx = i + 1 < located.size ? located[i + 1][:index] : cue_text.length
        excerpt = cue_text[start_idx...end_idx].to_s.strip
        excerpt = cue_text if excerpt.blank?
        row[:moment].merge("excerpt" => excerpt).except("anchor")
      end
    end

    def anchor_index(cue_text, anchor)
      needle = anchor.to_s.strip
      return 0 if needle.blank?
      return nil if needle.length < MIN_ANCHOR_CHARS && cue_text.length >= MIN_ANCHOR_CHARS

      exact = cue_text.index(needle)
      return exact unless exact.nil?

      tokens = needle.split(/\s+/).map { |token| Regexp.escape(token) }.reject(&:blank?)
      return nil if tokens.empty?

      match = cue_text.match(Regexp.new(tokens.join('\s+'), Regexp::IGNORECASE | Regexp::MULTILINE))
      match&.begin(0)
    end

    def assign_moments_to_segments(moments, segments)
      remaining = moments.dup
      segments.map do |segment|
        match_idx = remaining.find_index do |moment|
          Array(moment["observee_labels"]).any? do |label|
            token = label.to_s.strip.split(/\s+/).first.to_s
            token.length >= 2 && segment.match?(/\b#{Regexp.escape(token)}\b/i)
          end
        end
        moment =
          if match_idx
            remaining.delete_at(match_idx)
          else
            remaining.shift || moments.first
          end
        moment.merge(
          "excerpt" => segment,
          "reason" => [moment["reason"], "split_by_discourse_marker"].reject(&:blank?).join("; ")
        ).except("anchor")
      end
    end

    def fallback_moment(cue_text:, speaker:, reason:)
      {
        "ogo_worthy" => false,
        "observer_label" => speaker.to_s,
        "observee_labels" => [],
        "observer_company_teammate_id" => nil,
        "observee_company_teammate_ids" => [],
        "excerpt" => cue_text.to_s,
        "reason" => reason.to_s
      }
    end

    def sanitize_id(raw)
      id = raw.presence&.to_i
      return nil if id.blank? || id.zero?
      return nil unless @valid_teammate_ids.include?(id)

      id
    end
  end
end
