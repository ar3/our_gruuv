# frozen_string_literal: true

module Transcripts
  # Parse caption atoms → merge same-speaker blocks → split distinct shout-outs.
  class MomentCuesService
    def self.call(raw:)
      atoms = ParseCuesService.call(raw: raw)
      merged = MergeCuesService.call(cues: atoms)
      SplitDistinctShoutOutsService.call(cues: merged)
    end
  end
end
