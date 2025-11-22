class PeopleController < ApplicationController
  layout 'authenticated-v2-0'
  before_action :require_login, except: [:public]
  after_action :verify_authorized
  
  helper_method :person

  def public
    authorize person, policy_class: PersonPolicy
    # Public view - showcase public observations and milestones across all organizations
    # Use unauthenticated layout
    render layout: 'application'
    
    # Get all public observations where this person is observed
    teammate_ids = person.teammates.pluck(:id)
    @public_observations = if teammate_ids.any?
      Observation.public_observations
        .joins(:observees)
        .where(observees: { teammate_id: teammate_ids })
        .published
        .includes(:observer, :observed_teammates)
        .order(observed_at: :desc)
        .decorate
    else
      Observation.none.decorate
    end
    
    # Get all milestones across all organizations
    @milestones = if person.teammates.exists?
      TeammateMilestone.joins(:teammate)
        .where(teammates: { person: person })
        .includes(:ability, :certified_by)
        .order(attained_at: :desc)
    else
      TeammateMilestone.none
    end
  end

  def connect_google_identity
    authorize person, policy_class: PersonPolicy
    redirect_to "/auth/google_oauth2", data: { turbo: false }
  end

  def disconnect_identity
    authorize person, policy_class: PersonPolicy
    identity = person.person_identities.find(params[:id])
    
    unless person.can_disconnect_identity?(identity)
      redirect_to organization_person_path(current_organization, person), alert: 'Cannot disconnect this account. Please add another Google account first.'
      return
    end
    
    if identity.destroy
      redirect_to organization_person_path(current_organization, person), notice: 'Account disconnected successfully!'
    else
      redirect_to organization_person_path(current_organization, person), alert: 'Failed to disconnect account. Please try again.'
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to organization_person_path(current_organization, person), alert: 'Account not found.'
  end

  def person
    @person ||= if params[:id].present?
                  Person.find(params[:id])
                else
                  current_person
                end
  end

  private

  def require_login
    unless current_person
      redirect_to root_path, alert: 'Please log in to access your profile'
    end
  end
end 