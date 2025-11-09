# Test-only authentication controller for system tests
# This controller is only loaded in test environment
class Test::AuthController < ApplicationController
  # Only allow in test environment
  before_action :ensure_test_environment
  
  def sign_in
    teammate_id = params[:teammate_id]
    person_id = params[:person_id] # Legacy support
    organization_id = params[:organization_id] # Legacy support
    redirect_to = params[:redirect_to]
    
    teammate = if teammate_id.present?
      Teammate.find(teammate_id)
    elsif person_id.present?
      person = Person.find(person_id)
      # Find or create teammate
      if organization_id.present?
        organization = Organization.find(organization_id)
        person.teammates.find_or_create_by!(organization: organization) do |t|
          t.type = 'CompanyTeammate'
          t.first_employed_at = nil
          t.last_terminated_at = nil
        end
      else
        person.active_teammates.first || ensure_teammate_for_person(person)
      end
    else
      render json: { error: 'teammate_id or person_id is required' }, status: :bad_request
      return
    end
    
    # Set session
    session[:current_company_teammate_id] = teammate.id
    
    # If redirect_to is provided, redirect there instead of returning JSON
    if redirect_to.present?
      redirect_to redirect_to
    else
      render json: { 
        success: true, 
        teammate: { id: teammate.id },
        person: { id: teammate.person.id, name: teammate.person.display_name },
        organization: teammate.organization.name
      }
    end
  end
  
  def sign_out
    session.clear
    render json: { success: true }
  end
  
  def current_user
    if current_company_teammate
      render json: { 
        success: true, 
        teammate: { id: current_company_teammate.id },
        person: { id: current_person.id, name: current_person.display_name },
        organization: current_organization.name
      }
    else
      render json: { success: false, message: 'No user signed in' }
    end
  end
  
  private
  
  def ensure_test_environment
    unless Rails.env.test?
      render json: { error: 'This controller is only available in test environment' }, status: :forbidden
    end
  end
end
