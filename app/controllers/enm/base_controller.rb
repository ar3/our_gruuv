class Enm::BaseController < ApplicationController
  # Use a simple layout for ENM
  layout 'enm'
  
  private
  
  def authenticate_person!
    # Override to do nothing - ENM is completely public
  end
  
  def verify_authorized
    # Override to do nothing - ENM has no authorization
  end
  
  def verify_policy_scoped
    # Override to do nothing - ENM has no authorization
  end
end
