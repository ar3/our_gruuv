class FeedbackRequestPolicy < ApplicationPolicy
  def show?
    return false unless viewing_teammate
    return false if viewing_teammate.terminated?
    
    # Creator (requestor) can view
    return true if viewing_teammate == record.requestor_teammate
    
    # Subject of the request can view (but not edit/update)
    return true if viewing_teammate == record.subject_of_feedback_teammate
    
    # Responders can only see the answer (feedback response) page, not the show page
    false
  end

  def new?
    create?
  end

  def create?
    return false unless viewing_teammate
    return false if viewing_teammate.terminated?
    
    # For new records without a subject, allow if user is in the organization
    # The actual authorization will be checked when creating with a specific subject
    subject_teammate = record.subject_of_feedback_teammate
    # If association isn't loaded but ID is set, try to load it as CompanyTeammate
    if subject_teammate.nil? && record.subject_of_feedback_teammate_id.present?
      subject_teammate = CompanyTeammate.find_by(id: record.subject_of_feedback_teammate_id)
    end
    
    # If no subject set yet (new action), allow if user is in organization
    return true if subject_teammate.nil? && viewing_teammate.organization.present?
    
    return false unless subject_teammate
    
    # Check if user has can_manage_employment - they can create feedback for anyone
    if viewing_teammate.is_a?(CompanyTeammate) && viewing_teammate.can_manage_employment?
      return true
    end
    
    # Must be in same organization
    return false unless viewing_teammate.organization == subject_teammate.organization
    
    # Subject themselves (compare by ID to handle different object instances)
    return true if viewing_teammate.id == subject_teammate.id
    
    # Manager check - need to ensure both are CompanyTeammates
    if viewing_teammate.is_a?(CompanyTeammate) && subject_teammate.is_a?(CompanyTeammate)
      return true if viewing_teammate.in_managerial_hierarchy_of?(subject_teammate)
    end
    
    false
  end

  def edit?
    update?
  end

  def update?
    return false unless viewing_teammate
    return false if viewing_teammate.terminated?
    
    # Only the requestor teammate
    viewing_teammate == record.requestor_teammate
  end

  def destroy?
    return true if admin_bypass?
    return false unless viewing_teammate
    return false if viewing_teammate.terminated?
    
    # Only the requestor teammate (calls soft_delete! instead of actual destroy)
    viewing_teammate == record.requestor_teammate
  end

  def answer?
    return false unless viewing_teammate
    return false if viewing_teammate.terminated?
    
    # Must be a designated responder
    record.responders.include?(viewing_teammate)
  end

  def add_responder?
    return false unless viewing_teammate
    return false if viewing_teammate.terminated?
    
    # Only the requestor teammate
    viewing_teammate == record.requestor_teammate
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      
      # Users can see requests where they are the requestor, subject, or a responder
      # Use table name for id so the condition is unambiguous when scope is joined (e.g. with feedback_request_responders)
      scope.where(
        "(feedback_requests.requestor_teammate_id = ? OR feedback_requests.subject_of_feedback_teammate_id = ? OR feedback_requests.id IN (?))",
        viewing_teammate.id,
        viewing_teammate.id,
        FeedbackRequestResponder.where(company_teammate: viewing_teammate).select(:feedback_request_id)
      )
    end
  end
end
