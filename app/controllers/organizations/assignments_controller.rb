class Organizations::AssignmentsController < ApplicationController
  before_action :set_organization
  before_action :set_assignment, only: [:show, :edit, :update, :destroy]

  def index
    @assignments = @organization.assignments.includes(:assignment_outcomes, :published_external_reference, :draft_external_reference, :abilities).ordered
    render layout: 'authenticated-v2-0'
  end

  def show
    render layout: 'authenticated-v2-0'
  end

  def new
    @assignment = @organization.assignments.build
    render layout: 'authenticated-v2-0'
  end

  def create
    @assignment = @organization.assignments.build(assignment_params)

    if @assignment.save
      # Create external references if URLs provided
      create_external_references(@assignment, params[:assignment])
      
      # Create outcomes from textarea if provided
      if params[:assignment][:outcomes_textarea].present?
        @assignment.create_outcomes_from_textarea(params[:assignment][:outcomes_textarea])
      end
      
      redirect_to organization_assignment_path(@organization, @assignment), notice: 'Assignment was successfully created.'
    else
      # Preserve outcomes_textarea for re-render
      @assignment.outcomes_textarea = params[:assignment][:outcomes_textarea] if params[:assignment][:outcomes_textarea].present?
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    render layout: 'authenticated-v2-0'
  end

  def update
    if @assignment.update(assignment_params)
      # Update external references
      update_external_references(@assignment, params[:assignment])
      
      # Handle existing outcomes updates and deletions
      handle_existing_outcomes(params)
      
      # Handle new outcomes from textarea
      if params[:assignment][:outcomes_textarea].present?
        @assignment.create_outcomes_from_textarea(params[:assignment][:outcomes_textarea])
      end
      
      redirect_to organization_assignment_path(@organization, @assignment), notice: 'Assignment was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @assignment.destroy
    redirect_to organization_assignments_path(@organization), notice: 'Assignment was successfully deleted.'
  end

  private

  def set_organization
    @organization = Organization.find(params[:organization_id])
  end

  def set_assignment
    @assignment = @organization.assignments.find(params[:id])
  end

  def assignment_params
    params.require(:assignment).permit(:title, :tagline, :required_activities, :handbook)
  end

  def create_external_references(assignment, params)
    if params[:published_source_url].present?
      assignment.create_published_external_reference!(
        url: params[:published_source_url],
        reference_type: 'published'
      )
    end
    
    if params[:draft_source_url].present?
      assignment.create_draft_external_reference!(
        url: params[:draft_source_url],
        reference_type: 'draft'
      )
    end
  end

  def update_external_references(assignment, params)
    # Update or create published reference
    if params[:published_source_url].present?
      if assignment.published_external_reference
        assignment.published_external_reference.update!(url: params[:published_source_url])
      else
        assignment.create_published_external_reference!(url: params[:published_source_url], reference_type: 'published')
      end
    elsif assignment.published_external_reference
      assignment.published_external_reference.destroy
    end
    
    # Update or create draft reference
    if params[:draft_source_url].present?
      if assignment.draft_external_reference
        assignment.draft_external_reference.update!(url: params[:draft_source_url])
      else
        assignment.create_draft_external_reference!(url: params[:draft_source_url], reference_type: 'draft')
      end
    elsif assignment.draft_external_reference
      assignment.draft_external_reference.destroy
    end
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
