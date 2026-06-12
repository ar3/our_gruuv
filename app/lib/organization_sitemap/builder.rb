# frozen_string_literal: true

module OrganizationSitemap
  class Builder
    def initialize(context:)
      @context = context
    end

    def sections
      grouped = entries.group_by(&:section_label)
      Registry.section_definitions.filter_map do |section|
        section_label = resolve_section_label(section)
        section_entries = grouped[section_label] || []
        next if section_entries.empty?

        {
          label: section_label,
          icon: section[:icon],
          entries: section_entries
        }
      end
    end

    def entries
      @entries ||= dedupe_entries(build_entries)
    end

    def search(query)
      return [] if query.to_s.strip.blank?

      entries.select { |entry| entry.matches_query?(query) }
    end

    private

    attr_reader :context

    def build_entries
      Registry.section_definitions.flat_map do |section|
        section[:pages].filter_map do |page|
          build_entry(section, page)
        end
      end
    end

    def build_entry(section, page)
      return unless context.allowed?(page[:policy])

      path = context.resolve_path(page[:path])
      return if path.blank?

      Entry.new(
        key: page[:key].to_s,
        label: context.resolve_label(page[:label]),
        path: path,
        path_key: path_key_for(path),
        icon: page[:icon],
        section_label: resolve_section_label(section),
        synonyms: Array(page[:synonyms]),
        goal: page[:goal].to_s
      )
    end

    def dedupe_entries(raw_entries)
      raw_entries.each_with_object({}) do |entry, merged|
        existing = merged[entry.path_key]
        if existing
          merged[entry.path_key] = merge_entries(existing, entry)
        else
          merged[entry.path_key] = entry
        end
      end.values
    end

    def merge_entries(primary, duplicate)
      Entry.new(
        key: primary.key,
        label: primary.label,
        path: primary.path,
        path_key: primary.path_key,
        icon: primary.icon,
        section_label: primary.section_label,
        synonyms: (primary.synonyms + duplicate.synonyms).uniq,
        goal: primary.goal
      )
    end

    def resolve_section_label(section)
      label = section[:label]
      label.respond_to?(:call) ? label.call(context) : label.to_s
    end

    def path_key_for(url)
      uri = URI.parse(url)
      path = uri.path
      return path if uri.query.blank?

      params = Rack::Utils.parse_nested_query(uri.query)
      "#{path}?#{Rack::Utils.build_nested_query(params.sort.to_h)}"
    rescue URI::InvalidURIError
      url.to_s
    end
  end
end
