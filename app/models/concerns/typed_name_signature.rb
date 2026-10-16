# frozen_string_literal: true

# "Type your full name" attestation helper (JD, milestone awards, cosign).
module TypedNameSignature
  extend ActiveSupport::Concern

  class_methods do
    def normalize_typed_name(value)
      value.to_s.gsub(/\s+/, " ").strip.downcase
    end
  end

  def typed_name_matches?(typed_name, person)
    expected = person&.all_names_display_name
    return false if expected.blank?

    self.class.normalize_typed_name(typed_name) == self.class.normalize_typed_name(expected)
  end
end
