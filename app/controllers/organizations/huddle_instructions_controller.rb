class Organizations::HuddleInstructionsController < ApplicationController
  before_action :set_organization
  before_action :set_huddle_instruction, only: [:edit, :update, :destroy]
  
  def index
    @huddle_instructions = @organization.huddle_instructions.includes(:huddles)
  end
  
  def new
    @huddle_instruction = @organization.huddle_instructions.build
  end
  
  def create
    @huddle_instruction = @organization.huddle_instructions.build(huddle_instruction_params)
    
    if @huddle_instruction.save
      redirect_to organizations_path, notice: 'Huddle instruction was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @huddle_instruction.update(huddle_instruction_params)
      redirect_to organizations_path, notice: 'Huddle instruction was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @huddle_instruction.destroy
    redirect_to organizations_path, notice: 'Huddle instruction was successfully deleted.'
  end
  
  private
  
  def set_organization
    @organization = Organization.find(params[:organization_id])
  end
  
  def set_huddle_instruction
    @huddle_instruction = @organization.huddle_instructions.find(params[:id])
  end
  
  def huddle_instruction_params
    params.require(:huddle_instruction).permit(:instruction_alias, :slack_channel)
  end
end
