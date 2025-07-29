class AssignmentsController < ApplicationController
  before_action :set_assignment, only: [:show, :edit, :update, :destroy]

  def index
    @assignments = Assignment.includes(:company, :assignment_outcomes).ordered
  end

  def show
  end

  def new
    @assignment = Assignment.new
    @assignment.company_id = params[:company_id] if params[:company_id]
    @companies = Organization.companies.ordered
  end

  def create
    @assignment = Assignment.new(assignment_params)
    @companies = Organization.companies.ordered

    if @assignment.save
      # Create outcomes from textarea if provided
      if params[:assignment][:outcomes_textarea].present?
        @assignment.create_outcomes_from_textarea(params[:assignment][:outcomes_textarea])
      end
      
      redirect_to @assignment, notice: 'Assignment was successfully created.'
    else
      # Preserve outcomes_textarea for re-render
      @assignment.outcomes_textarea = params[:assignment][:outcomes_textarea] if params[:assignment][:outcomes_textarea].present?
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @companies = Organization.companies.ordered
  end

  def update
    @companies = Organization.companies.ordered
    
    if @assignment.update(assignment_params)
      # Handle existing outcomes updates and deletions
      handle_existing_outcomes(params)
      
      # Handle new outcomes from textarea
      if params[:assignment][:outcomes_textarea].present?
        @assignment.create_outcomes_from_textarea(params[:assignment][:outcomes_textarea])
      end
      
      redirect_to @assignment, notice: 'Assignment was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @assignment.destroy
    redirect_to assignments_url, notice: 'Assignment was successfully deleted.'
  end

  private

  def set_assignment
    @assignment = Assignment.find(params[:id])
  end

  def assignment_params
    params.require(:assignment).permit(:title, :tagline, :required_activities, :handbook, :company_id, :published_source_url, :draft_source_url)
  end

  def handle_existing_outcomes(params)
    @assignment.assignment_outcomes.each do |outcome|
      outcome_id = outcome.id.to_s
      
      # Check if this outcome is marked for deletion
      if params[:assignment]["outcome_delete_#{outcome_id}"] == "1"
        outcome.destroy
      else
        # Update the outcome with new values
        description_param = params[:assignment]["outcome_description_#{outcome_id}"]
        type_param = params[:assignment]["outcome_type_#{outcome_id}"]
        
        if description_param.present? && type_param.present?
          outcome.update!(
            description: description_param.strip,
            outcome_type: type_param
          )
        end
      end
    end
  end
end
