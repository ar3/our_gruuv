class PersonOrganizationAccess < ApplicationRecord
  belongs_to :person
  belongs_to :organization
  
  # Validations
  validates :person_id, uniqueness: { scope: :organization_id }
  
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
  
  # Class methods for permission checking
  def self.can_manage_employment?(person, organization)
    access = find_by(person: person, organization: organization)
    access&.can_manage_employment? || false
  end
  
  def self.can_create_employment?(person, organization)
    access = find_by(person: person, organization: organization)
    access&.can_create_employment? || false
  end
  
  def self.can_manage_maap?(person, organization)
    access = find_by(person: person, organization: organization)
    access&.can_manage_maap? || false
  end
  
  def self.can_manage_employment_in_hierarchy?(person, organization)
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
end
