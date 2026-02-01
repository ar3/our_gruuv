class Aspiration < ApplicationRecord
  include ModelSemanticVersionable

  belongs_to :company, class_name: 'Organization'
  belongs_to :department, optional: true
  has_many :observation_ratings, as: :rateable, dependent: :destroy
  has_many :observations, through: :observation_ratings
  has_many :comments, as: :commentable, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :company_id }
  validates :sort_order, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :department_must_belong_to_company

  # Soft delete implementation following existing pattern
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def deleted?
    deleted_at.present?
  end

  # Scope for ordering by sort_order
  scope :ordered, -> { order(:sort_order, :name) }

  # Scope for finding aspirations for a company
  scope :for_company, ->(company) { where(company_id: company.is_a?(Integer) ? company : company.id) }
  
  # Scope for finding aspirations for a department
  scope :for_department, ->(department) { where(department: department) }
  
  # Scope for finding aspirations within an organization hierarchy
  scope :within_hierarchy, ->(organization) {
    org_ids = organization.self_and_descendants.pluck(:id)
    where(company_id: org_ids)
  }

  # Finder method that handles both id and id-name formats
  def self.find_by_param(param)
    # If param is just a number, use it as id
    return find(param) if param.to_s.match?(/\A\d+\z/)
    
    # Otherwise, extract id from id-name format
    id = param.to_s.split('-').first
    find(id)
  end

  def to_param
    "#{id}-#{name.parameterize}"
  end

  private

  def department_must_belong_to_company
    return unless department.present?
    
    if department.company_id != company_id
      errors.add(:department, 'must belong to the same company')
    end
  end
end
