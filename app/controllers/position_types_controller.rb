class PositionTypesController < ApplicationController
  before_action :set_position_type, only: [:show, :edit, :update, :destroy]
  before_action :set_organization

  def index
    @position_types = PositionType.where(organization: @organization).ordered
    respond_to do |format|
      format.html
      format.json { render json: @position_types }
    end
  end

  def show
  end

  def new
    @position_type = PositionType.new(organization: @organization)
  end

  def edit
  end

  def create
    @position_type = PositionType.new(position_type_params)
    @position_type.organization = @organization

    if @position_type.save
      redirect_to @position_type, notice: 'Position type was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @position_type.update(position_type_params)
      redirect_to @position_type, notice: 'Position type was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @position_type.destroy
    redirect_to position_types_path, notice: 'Position type was successfully deleted.'
  end

  private

  def set_position_type
    @position_type = PositionType.find(params[:id])
  end

  def set_organization
    @organization = current_organization
  end

  def position_type_params
    params.require(:position_type).permit(:position_major_level_id, :external_title, :alternative_titles, :position_summary)
  end
end
