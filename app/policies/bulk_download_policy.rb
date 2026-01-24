class BulkDownloadPolicy < ApplicationPolicy
  def show?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true # Anyone can view download history
  end

  def download?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    
    # og_admin or can_manage_employment can download anyone's file
    return true if admin_bypass?
    return true if viewing_teammate.can_manage_employment?
    
    # Others can only download their own files
    record.downloaded_by_id == viewing_teammate.id
  end

  private

  def organization_in_hierarchy?
    return false unless viewing_teammate
    teammate_org = viewing_teammate.organization
    return false unless teammate_org
    
    record_org = record.company
    record_org.id == teammate_org.id || 
      teammate_org.self_and_descendants.map(&:id).include?(record_org.id) ||
      record_org.self_and_descendants.map(&:id).include?(teammate_org.id)
  end
end
