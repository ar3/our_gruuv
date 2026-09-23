# frozen_string_literal: true

# Immutable employee signature of their true job description.
# document_html is the page wording at signed_at. snapshot is the structured copy
# (assignments, energy, missing required rows, milestones) for later compliance views.
class JobDescriptionAcknowledgement < ApplicationRecord
  belongs_to :company_teammate, class_name: "CompanyTeammate"
  belongs_to :organization
  belongs_to :employment_tenure, optional: true
  belongs_to :position, optional: true

  validates :typed_name, :signed_at, :document_html, presence: true
  validates :snapshot, presence: true
  validate :typed_name_matches_person_government_name
  validate :tenure_belongs_to_teammate

  def self.normalize_name(value)
    value.to_s.gsub(/\s+/, " ").strip.downcase
  end

  def position_name
    snapshot.is_a?(Hash) ? snapshot["position_name"].presence : nil
  end

  def request_info_hash
    (request_info.presence || {}).with_indifferent_access
  end

  private

  def typed_name_matches_person_government_name
    expected = company_teammate&.person&.government_first_then_last_display_name
    return if self.class.normalize_name(typed_name) == self.class.normalize_name(expected) && expected.present?

    errors.add(:typed_name, "must match your full name")
  end

  def tenure_belongs_to_teammate
    return if employment_tenure.blank?
    return if employment_tenure.teammate_id == company_teammate_id

    errors.add(:employment_tenure, "must belong to this teammate")
  end
end
