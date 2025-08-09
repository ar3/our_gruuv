class EmploymentTenure < ApplicationRecord
  belongs_to :person
  belongs_to :company, class_name: 'Organization'
  belongs_to :position
  belongs_to :manager, class_name: 'Person', optional: true

  validates :started_at, presence: true
  validates :ended_at, comparison: { greater_than: :started_at }, allow_nil: true
  validate :no_overlapping_active_tenures_for_same_person_and_company

  scope :active, -> { where(ended_at: nil) }
  scope :inactive, -> { where.not(ended_at: nil) }
  scope :for_person, ->(person) { where(person: person) }
  scope :for_company, ->(company) { where(company: company) }

  def active?
    ended_at.nil?
  end

  def inactive?
    !active?
  end

  private

  def no_overlapping_active_tenures_for_same_person_and_company
    return unless person_id && company_id && started_at

    overlapping_tenures = EmploymentTenure
      .where(person: person, company: company)
      .where.not(id: id) # Exclude current record if updating
      .where('(ended_at IS NULL OR ended_at > ?) AND started_at < ?', started_at, ended_at || Date.current)

    if overlapping_tenures.exists?
      errors.add(:base, 'Cannot have overlapping active employment tenures for the same person and company')
    end
  end
end
