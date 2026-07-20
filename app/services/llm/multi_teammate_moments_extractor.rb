# frozen_string_literal: true

# Thin multi-subject adapter: same SlackMomentsExtractor prompt/models per confirmed teammate.
module Llm
  class MultiTeammateMomentsExtractor
    def self.model_id
      SlackMomentsExtractor.model_id
    end

    def self.stronger_model_id
      SlackMomentsExtractor.stronger_model_id
    end

    def self.prompt_version
      SlackMomentsExtractor::PROMPT_VERSION
    end

    INCLUDE_CONFIDENCE_THRESHOLD = SlackMomentsExtractor::INCLUDE_CONFIDENCE_THRESHOLD

    # Runs the Slack OGO prompt once per subject over the same chunk (exact shared prompt).
    def self.call_for_subject(
      chunk_text:,
      subject_name:,
      context_text: nil,
      context_catalog: nil,
      organization_id: nil,
      parent: nil,
      triggered_by_teammate_id: nil,
      model_id: nil
    )
      SlackMomentsExtractor.call(
        chunk_text: format_chunk_as_source_block(chunk_text),
        subject_name: subject_name,
        context_text: context_text,
        context_catalog: context_catalog,
        organization_id: organization_id,
        parent: parent,
        triggered_by_teammate_id: triggered_by_teammate_id,
        model_id: model_id
      )
    end

    def self.format_chunk_as_source_block(chunk_text)
      <<~MSG.strip
        [source=transcript_or_notes] username=transcript user= ts= channel_id= permalink=
        #{chunk_text}
      MSG
    end
  end
end
