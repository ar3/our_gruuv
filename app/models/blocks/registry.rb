# frozen_string_literal: true

module Blocks
  module Registry
    MAP = {
      "text" => Blocks::Text
    }.freeze

    module_function

    def fetch(block_type)
      MAP.fetch(block_type.to_s) do
        raise KeyError, "Unknown block type: #{block_type.inspect}"
      end
    end

    def types
      MAP.keys
    end
  end
end
