class Teammate < ApplicationRecord
  # Single Table Inheritance
  self.inheritance_column = 'type'
  
  belongs_to :person
  belongs_to :organization
  
  # Reverse associations
  has_many :person_milestones, dependent: :nullify
  has_many :assignment_check_ins, dependent: :nullify
  has_many :assignment_tenures, dependent: :nullify
  has_many :employment_tenures, dependent: :nullify
  has_many :huddle_feedbacks, dependent: :nullify
  has_many :huddle_participants, dependent: :nullify
  
  # Validations
  validates :person_id, uniqueness: { scope: :organization_id }
  validates :first_employed_at, presence: true, if: :employed?
  validates :last_terminated_at, comparison: { greater_than: :first_employed_at }, allow_nil: true
  
  # Scopes
  scope :for_organization_hierarchy, ->(org) { 
    if org.company?
      where(organization: org.self_and_descendants)
    else
      where(organization: [org, org.parent].compact)
    end
  }
  scope :with_employment_management, -> { where(can_manage_employment: true) }
  scope :with_employment_creation, -> { where(can_create_employment: true) }
  scope :with_maap_management, -> { where(can_manage_maap: true) }
  
  # Employment state scopes
  scope :followers, -> { where(first_employed_at: nil, last_terminated_at: nil) }
  scope :unassigned_employees, -> { where.not(first_employed_at: nil).where(last_terminated_at: nil) }
  scope :assigned_employees, -> { where.not(first_employed_at: nil).where(last_terminated_at: nil) }
  scope :terminated, -> { where.not(last_terminated_at: nil) }
  
  # Instance methods
  def can_manage_employment?
    self[:can_manage_employment] == true
  end
  
  def can_create_employment?
    self[:can_create_employment] == true
  end
  
  def can_manage_maap?
    self[:can_manage_maap] == true
  end
  
  # Employment state methods
  def follower?
    first_employed_at.nil? && last_terminated_at.nil?
  end
  
  def unassigned_employee?
    first_employed_at.present? && last_terminated_at.nil? && !has_active_employment_tenure?
  end
  
  def assigned_employee?
    first_employed_at.present? && last_terminated_at.nil? && has_active_employment_tenure?
  end
  
  def terminated?
    last_terminated_at.present?
  end
  
  def employed?
    first_employed_at.present? && last_terminated_at.nil?
  end
  
  private
  
  def has_active_employment_tenure?
    # Check if person has active employment tenure in this organization
    person.employment_tenures.active.exists?(company: organization)
  end
  
  # Class methods for permission checking
  def self.can_manage_employment?(person, organization)
    return true if person.og_admin?
    access = find_by(person: person, organization: organization)
    access&.can_manage_employment? || false
  end
  
  def self.can_create_employment?(person, organization)
    return true if person.og_admin?
    access = find_by(person: person, organization: organization)
    access&.can_create_employment? || false
  end
  
  def self.can_manage_maap?(person, organization)
    return true if person.og_admin?
    access = find_by(person: person, organization: organization)
    access&.can_manage_maap? || false
  end
  
  def self.can_manage_employment_in_hierarchy?(person, organization)
    # og_admin users have access to all organizations
    return true if person.og_admin?
    
    organizations_to_check = if organization.company?
      organization.self_and_descendants
    else
      [organization, organization.parent].compact
    end
    
    # Find the most specific access record (current org first, then parent)
    access = nil
    if organization.company?
      access = where(organization: organizations_to_check).find_by(person: person)
    else
      # Check current organization first, then parent
      # Return true if either has the permission
      current_access = find_by(person: person, organization: organization)
      parent_access = find_by(person: person, organization: organization.parent) if organization.parent
      
      if current_access&.can_manage_employment? || parent_access&.can_manage_employment?
        return true
      else
        access = current_access || parent_access
      end
    end
    
    access&.can_manage_employment? || false
  end
  
  def self.can_manage_maap_in_hierarchy?(person, organization)
    # og_admin users have access to all organizations
    return true if person.og_admin?
    
    organizations_to_check = if organization.company?
      organization.self_and_descendants
    else
      [organization, organization.parent].compact
    end
    
    # Find the most specific access record (current org first, then parent)
    access = nil
    if organization.company?
      access = where(organization: organizations_to_check).find_by(person: person)
    else
      # Check current organization first, then parent
      # Return true if either has the permission
      current_access = find_by(person: person, organization: organization)
      parent_access = find_by(person: person, organization: organization.parent) if organization.parent
      
      if current_access&.can_manage_maap? || parent_access&.can_manage_maap?
        return true
      else
        access = current_access || parent_access
      end
    end
    
    access&.can_manage_maap? || false
  end

  def self.can_create_employment_in_hierarchy?(person, organization)
    # og_admin users have access to all organizations
    return true if person.og_admin?
    
    organizations_to_check = if organization.company?
      organization.self_and_descendants
    else
      [organization, organization.parent].compact
    end
    
    # Find the most specific access record (current org first, then parent)
    access = nil
    if organization.company?
      access = where(organization: organizations_to_check).find_by(person: person)
    else
      # Check current organization first, then parent
      # Return true if either has the permission
      current_access = find_by(person: person, organization: organization)
      parent_access = find_by(person: person, organization: organization.parent) if organization.parent
      
      if current_access&.can_create_employment? || parent_access&.can_create_employment?
        return true
      else
        access = current_access || parent_access
      end
    end
    
    access&.can_create_employment? || false
  end
end
