# Test-only authentication controller for system tests
# This controller is only loaded in test environment
class Test::AuthController < ApplicationController
  # Only allow in test environment
  before_action :ensure_test_environment
  
  def sign_in
    person_id = params[:person_id]
    organization_id = params[:organization_id]
    redirect_to = params[:redirect_to]
    
    unless person_id.present?
      render json: { error: 'person_id is required' }, status: :bad_request
      return
    end
    
    person = Person.find(person_id)
    
    # Set session
    session[:current_person_id] = person.id
    
    # Set organization if provided
    if organization_id.present?
      organization = Organization.find(organization_id)
      person.update!(current_organization: organization)
    end
    
    # If redirect_to is provided, redirect there instead of returning JSON
    if redirect_to.present?
      redirect_to redirect_to
    else
      render json: { 
        success: true, 
        person: { id: person.id, name: person.display_name },
        organization: person.current_organization&.name
      }
    end
  end
  
  def sign_out
    session.clear
    render json: { success: true }
  end
  
  def current_user
    if current_person
      render json: { 
        success: true, 
        person: { id: current_person.id, name: current_person.display_name },
        organization: current_person.current_organization&.name
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
