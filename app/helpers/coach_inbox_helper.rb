# frozen_string_literal: true

module CoachInboxHelper
  def coach_inbox_expanded_subtype_keys(sections = @sections)
    Array(sections).flat_map { |section| section.subtypes.select(&:expanded).map { |subtype| subtype.key.to_s } }
  end

  def coach_inbox_toggle_expand_path(organization:, manager_id:, subtype_key:, expanded_keys: coach_inbox_expanded_subtype_keys)
    key = subtype_key.to_s
    next_keys = if expanded_keys.include?(key)
      expanded_keys - [key]
    else
      (expanded_keys + [key]).uniq
    end

    organization_coach_inbox_path(organization, manager_id: manager_id, expand: next_keys)
  end
end
