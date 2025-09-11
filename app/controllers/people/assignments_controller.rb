class People::AssignmentsController < ApplicationController
  layout 'authenticated-v2-0'
  before_action :require_authentication
  before_action :set_person
  before_action :set_assignment
  after_action :verify_authorized

  def show
    authorize @person, :manager?, policy_class: PersonPolicy
    load_assignment_data
  end

  def check_in_history
    authorize @person, :manager?, policy_class: PersonPolicy
    @check_ins = AssignmentCheckIn
      .where(person: @person, assignment: @assignment)
      .includes(:employee_completed_by, :manager_completed_by, :finalized_by)
      .order(check_in_started_on: :desc)
  end

  private

  def set_person
    @person = Person.find(params[:person_id])
  end

  def set_assignment
    @assignment = Assignment.find(params[:id])
  end

  def load_assignment_data
    @tenure = AssignmentTenure.most_recent_for(@person, @assignment)
    @open_check_in = AssignmentCheckIn.where(person: @person, assignment: @assignment).open.first
    @recent_check_ins = AssignmentCheckIn
      .where(person: @person, assignment: @assignment)
      .includes(:employee_completed_by, :manager_completed_by, :finalized_by)
      .order(check_in_started_on: :desc)
      .limit(5)
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access assignment details.'
    end
  end
end
