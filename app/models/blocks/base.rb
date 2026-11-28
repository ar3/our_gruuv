# frozen_string_literal: true

module Blocks
  class Base
    attr_reader :block

    def initialize(block)
      @block = block
    end

    def to_markdown
      block.content.to_s
    end

    def view_partial
      "blocks/#{block.block_type}"
    end

    def edit_partial
      "blocks/#{block.block_type}_edit"
    end
  end
end
