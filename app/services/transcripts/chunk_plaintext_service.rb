# frozen_string_literal: true

module Transcripts
  class ChunkPlaintextService
    CHUNK_CHARS = 48_000
    OVERLAP_CHARS = 1_500

    def self.call(text)
      new(text).call
    end

    def initialize(text)
      @text = text.to_s
    end

    def call
      return [@text] if @text.length <= CHUNK_CHARS

      chunks = []
      i = 0
      while i < @text.length
        chunk_end = [i + CHUNK_CHARS, @text.length].min
        chunks << @text[i...chunk_end]
        break if chunk_end >= @text.length

        i = chunk_end - OVERLAP_CHARS
        i = [i, 0].max
      end
      chunks
    end
  end
end
