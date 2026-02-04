class Department < ApplicationRecord
  # Associations
  belongs_to :company, class_name: 'Organization'
  belongs_to :parent_department, class_name: 'Department', optional: true
  has_many :child_departments, class_name: 'Department', foreign_key: 'parent_department_id', dependent: :destroy
  
  # Reverse associations - resources linked to this department
  has_many :abilities, dependent: :nullify
  has_many :aspirations, dependent: :nullify
  has_many :titles, dependent: :nullify
  has_many :assignments, dependent: :nullify
  has_many :seats, through: :titles
  
  # Third party associations (similar to Team)
  has_many :third_party_object_associations, as: :associatable, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :company, presence: true
  validate :parent_department_must_belong_to_same_company

  # Soft delete support
  scope :active, -> { where(deleted_at: nil) }
  scope :archived, -> { where.not(deleted_at: nil) }

  # Convenience scopes
  scope :ordered, -> { order(:name) }
  scope :for_company, ->(company) { where(company: company) }
  scope :root_departments, -> { where(parent_department_id: nil) }

  # Instance methods
  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def archived?
    deleted_at.present?
  end

  def active?
    deleted_at.nil?
  end

  # Hierarchy methods
  def self_and_descendants
    [self] + descendants
  end

  def descendants
    child_departments.active.flat_map { |child| [child] + child.descendants }
  end

  def self_and_ancestors
    [self] + ancestors_list
  end

  def ancestors_list
    parent_department ? [parent_department] + parent_department.ancestors_list : []
  end

  def ancestry_depth
    parent_department ? parent_department.ancestry_depth + 1 : 0
  end

  def root_department
    parent_department ? parent_department.root_department : self
  end

  def root?
    parent_department_id.nil?
  end

  # For helpers that expect organization-like API (e.g. CompanyLabelHelper)
  def root_company
    company
  end

  def display_name
    parent_department ? "#{parent_department.display_name} > #{name}" : name
  end

  def short_display_name
    name
  end

  # For URL generation (friendly URLs)
  def to_param
    "#{id}-#{name.parameterize}" if persisted?
  end

  # Find by param helper (handles both id and id-name formats)
  def self.find_by_param(param)
    return nil if param.blank?
    
    id = param.to_s.split('-').first
    find_by(id: id)
  end

  # Type checking helpers (for compatibility with views that check type)
  def department?
    true
  end

  def team?
    false
  end

  def company?
    false
  end

  # Slack group association (same pattern as Organization for channels edit)
  def slack_group_association
    third_party_object_associations.where(association_type: 'slack_group').first
  end

  def slack_group
    slack_group_association&.third_party_object
  end

  def slack_group_id
    slack_group&.third_party_id
  end

  def slack_group_id=(group_id)
    if group_id.present?
      group = company.third_party_objects.where(third_party_source: 'slack', third_party_object_type: 'group').find_by(third_party_id: group_id)
      if group
        slack_group_association&.destroy
        third_party_object_associations.create!(third_party_object: group, association_type: 'slack_group')
      end
    else
      slack_group_association&.destroy
    end
  end

  def kudos_channel_association
    third_party_object_associations.where(association_type: 'observation_kudos_channel').first
  end

  def kudos_channel
    kudos_channel_association&.third_party_object
  end

  def kudos_channel_id
    kudos_channel&.third_party_id
  end

  def kudos_channel_id=(channel_id)
    if channel_id.present?
      channel = company.third_party_objects.slack_channels.find_by(third_party_id: channel_id)
      if channel
        kudos_channel_association&.destroy
        third_party_object_associations.create!(third_party_object: channel, association_type: 'observation_kudos_channel')
      end
    else
      kudos_channel_association&.destroy
    end
  end

  private

  def parent_department_must_belong_to_same_company
    return unless parent_department.present?
    
    if parent_department.company_id != company_id
      errors.add(:parent_department, 'must belong to the same company')
    end
  end
end
