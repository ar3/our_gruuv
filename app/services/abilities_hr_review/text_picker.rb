# frozen_string_literal: true

module AbilitiesHrReview
  module TextPicker
    module_function

    def pick_text(desc_hash, override)
      h = desc_hash.is_a?(Hash) ? desc_hash.stringify_keys : {}
      o = override.to_s.presence
      return o if o

      h['proposed'].presence || h['normalized'].presence || h['raw'].presence
    end

    def pick_milestone_text(milestones_hash, n, override)
      o = override.to_s.presence
      return o if o

      h = (milestones_hash || {})[n.to_s]
      h = h.stringify_keys if h.is_a?(Hash)
      return '' unless h.is_a?(Hash)

      h['proposed'].presence || h['normalized'].presence || h['raw'].presence || ''
    end
  end
end
