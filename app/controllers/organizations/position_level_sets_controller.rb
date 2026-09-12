# frozen_string_literal: true

class Organizations::PositionLevelSetsController < Organizations::OrganizationNamespaceBaseController
  def show
    authorize @organization, :view_titles?

    @set_name = params[:name].to_s
    @position_major_levels = PositionMajorLevel.where(set_name: @set_name).order(:major_level)

    raise ActiveRecord::RecordNotFound if @position_major_levels.empty?
  end
end
