class EmploymentTenuresController < ApplicationController
  before_action :require_authentication
  before_action :set_employment_tenure, only: [:show, :edit, :update, :destroy]

  def index
    @employment_tenures = EmploymentTenure.includes(:person, :company, :position, :manager)
                                         .order(started_at: :desc)
                                         .decorate
  end

  def show
    @employment_tenure = @employment_tenure.decorate
  end

  def new
    @employment_tenure = EmploymentTenure.new
  end

  def create
    @employment_tenure = EmploymentTenure.new(employment_tenure_params)
    
    if @employment_tenure.save
      redirect_to @employment_tenure, notice: 'Employment tenure was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @employment_tenure.update(employment_tenure_params)
      redirect_to @employment_tenure, notice: 'Employment tenure was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @employment_tenure.destroy
    redirect_to employment_tenures_path, notice: 'Employment tenure was successfully deleted.'
  end

  private

  def set_employment_tenure
    @employment_tenure = EmploymentTenure.find(params[:id])
  end

  def employment_tenure_params
    params.require(:employment_tenure).permit(:person_id, :company_id, :position_id, :manager_id, :started_at, :ended_at)
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access employment tenures.'
    end
  end
end
