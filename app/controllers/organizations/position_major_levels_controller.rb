# frozen_string_literal: true

class Organizations::PositionMajorLevelsController < Organizations::OrganizationNamespaceBaseController
  before_action :set_position_major_level

  def show
    authorize @organization, :view_titles?

    @position_levels = @position_major_level.position_levels.order(:level)
    @titles = @organization.titles
      .where(position_major_level_id: @position_major_level.id)
      .includes(:department, :positions)
      .ordered
  end

  private

  def set_position_major_level
    @position_major_level = PositionMajorLevel.find(params[:id])
  end
end
