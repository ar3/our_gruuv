class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  def logout
    session.clear
    redirect_to root_path, notice: 'You have been logged out successfully!'
  end
  
  helper_method :current_person
  
  private
  
  def current_person
    @current_person ||= Person.find(session[:current_person_id]) if session[:current_person_id]
  end

  # Get person from session or create from params
  def get_or_create_person_from_session_or_params(params_key = :huddle)
    if session[:current_person_id]
      Person.find(session[:current_person_id])
    else
      find_or_create_person_from_params(params_key)
    end
  end

  # Find or create person from specific params
  def find_or_create_person_from_params(params_key = :huddle)
    # For join params, they're at the top level, not nested
    if params_key == :join
      email = params[:email]
      name = params[:name]
    else
      params_obj = params[params_key]
      email = params_obj[:email]
      name = params_obj[:name]
    end
    
    # Find or create the person
    person = Person.find_or_create_by!(email: email) do |p|
      p.full_name = name
    end
    
    # Update the name if the person already existed and the name is different
    if person.full_name != name
      person.update!(full_name: name)
    end
    
    person
  end
end
