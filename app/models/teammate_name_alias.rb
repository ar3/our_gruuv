# frozen_string_literal: true

# Transcript / shout-out nicknames for a teammate (e.g. "CJ" → Casey).
# Org-scoped via CompanyTeammate; used by TeammateResolver + first-pass roster.
class TeammateNameAlias < ApplicationRecord
  SOURCES = %w[manual transcript_learn].freeze
  BLOCKED_NORMALIZED = %w[
    team group everyone everybody all folks people folks the theteam marketing
    engineering sales ops operations company
  ].freeze

  belongs_to :company_teammate, class_name: "CompanyTeammate", foreign_key: "teammate_id",
                               inverse_of: :name_aliases
  alias_method :teammate, :company_teammate
  alias_method :teammate=, :company_teammate=

  belongs_to :created_by_company_teammate, class_name: "CompanyTeammate", optional: true

  before_validation :normalize_fields

  validates :name, presence: true, length: { maximum: 80 }
  validates :normalized_name, presence: true, length: { maximum: 80 }
  validates :source, inclusion: { in: SOURCES }
  validates :normalized_name, uniqueness: { scope: :teammate_id }
  validate :name_not_blocked
  validate :name_not_already_a_legal_name

  def self.normalize(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, " ").squish
  end

  def self.learnable?(raw)
    normalized = normalize(raw)
    return false if normalized.blank? || normalized.length < 2
    return false if BLOCKED_NORMALIZED.include?(normalized.delete(" "))
    return false if BLOCKED_NORMALIZED.include?(normalized)

    true
  end

  private

  def normalize_fields
    self.name = name.to_s.strip
    self.normalized_name = self.class.normalize(name)
  end

  def name_not_blocked
    return if normalized_name.blank?
    return if self.class.learnable?(name)

    errors.add(:name, "is not a useful teammate alias")
  end

  def name_not_already_a_legal_name
    person = company_teammate&.person
    return unless person

    known = [
      person.display_name,
      person.casual_name,
      person.first_name,
      person.middle_name,
      person.preferred_name,
      person.last_name,
      [person.first_name, person.last_name].compact_blank.join(" "),
      [person.first_name, person.middle_name, person.last_name].compact_blank.join(" ")
    ].map { |value| self.class.normalize(value) }.compact_blank.uniq

    return unless known.include?(normalized_name)

    errors.add(:name, "already matches this person's name")
  end
end
