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
      redirect_to @assignment, notice: 'Assignment was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @companies = Organization.companies.ordered
  end

  def update
    @companies = Organization.companies.ordered
    
    if @assignment.update(assignment_params)
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
    params.require(:assignment).permit(:title, :tagline, :required_activities, :handbook, :company_id)
  end
end
