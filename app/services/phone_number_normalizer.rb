# frozen_string_literal: true

# Normalizes phone numbers to E.164-ish form for uniqueness and SMS.
# US 10-digit numbers become +1XXXXXXXXXX (including mistaken "+317…" without country code).
class PhoneNumberNormalizer
  def self.call(raw)
    new(raw).call
  end

  # Forms that may already exist in the DB for the same handset (legacy unnormalized rows).
  def self.lookup_candidates(raw)
    normalized = call(raw)
    return [] if normalized.blank?

    digits = normalized.delete_prefix('+')
    candidates = [normalized, digits]

    if digits.length == 11 && digits.start_with?('1')
      ten = digits[1..]
      candidates << ten
      candidates << "1#{ten}"
      candidates << "+1#{ten}"
      candidates << "+#{ten}" # legacy: "+" + 10-digit US number, no country code
    elsif digits.length == 10
      candidates << "1#{digits}"
      candidates << "+1#{digits}"
      candidates << "+#{digits}"
    end

    candidates.map(&:presence).compact.uniq
  end

  def initialize(raw)
    @raw = raw.to_s.strip
  end

  def call
    return nil if @raw.blank?

    digits = @raw.gsub(/\D/, '')
    return nil if digits.blank?

    # 10 digits → US national (whether or not the user typed a leading "+")
    if digits.length == 10
      "+1#{digits}"
    elsif digits.length == 11 && digits.start_with?('1')
      "+#{digits}"
    elsif @raw.start_with?('+')
      "+#{digits}"
    else
      "+#{digits}"
    end
  end
end
