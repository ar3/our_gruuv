# frozen_string_literal: true

module Blocks
  class Text < Base
    Settings = {}.freeze

    def self.block_type
      "text"
    end

    def to_markdown
      block.content.to_s
    end
  end
end
