# frozen_string_literal: true

module OrganizationSitemap
  Entry = Struct.new(
    :key,
    :label,
    :path,
    :path_key,
    :icon,
    :section_label,
    :synonyms,
    :goal,
    keyword_init: true
  ) do
    def searchable_text
      ([label, section_label] + Array(synonyms) + [goal]).join(" ").downcase
    end

    def matches_query?(query)
      tokens = query.to_s.downcase.split(/\s+/).grep(/\S/)
      return false if tokens.empty?

      text = searchable_text
      tokens.all? { |token| text.include?(token) }
    end

    def synonym_list
      Array(synonyms).join(", ")
    end
  end
end
