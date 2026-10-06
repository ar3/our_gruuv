# frozen_string_literal: true

module OgCandidateIdentityHelper
  def og_identity_alternates(item, key)
    raw = item[key] || item[key.to_s] || item[key.to_sym]
    Array(raw).filter_map do |alt|
      hash = alt.respond_to?(:to_h) ? alt.to_h.stringify_keys : {}
      id = hash["company_teammate_id"].presence&.to_i
      name = hash["name"].to_s.strip
      next if id.blank? || name.blank?

      { company_teammate_id: id, name: name }
    end.first(3)
  end
end
