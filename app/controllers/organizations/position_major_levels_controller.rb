# frozen_string_literal: true

class Organizations::PositionMajorLevelsController < Organizations::OrganizationNamespaceBaseController
  before_action :set_position_major_level, only: :show

  def index
    authorize @organization, :view_titles?

    @position_major_levels = PositionMajorLevel
      .includes(:position_levels)
      .order(:set_name, :major_level)

    major_ids = @position_major_levels.map(&:id)

    @titles_by_major_id = @organization.titles
      .unarchived
      .where(position_major_level_id: major_ids)
      .left_joins(:department)
      .includes(:department)
      .order(Arel.sql("departments.name ASC NULLS LAST"), :external_title)
      .group_by(&:position_major_level_id)

    @positions_by_level_id = @organization.positions
      .unarchived
      .joins(:position_level, :title)
      .left_joins(title: :department)
      .where(position_levels: { position_major_level_id: major_ids })
      .includes(:position_level, title: :department)
      .order(Arel.sql("departments.name ASC NULLS LAST"), "titles.external_title", "position_levels.level")
      .group_by(&:position_level_id)
  end

  def show
    authorize @organization, :view_titles?

    @position_levels = @position_major_level.position_levels.order(:level)
    @titles = @organization.titles
      .unarchived
      .where(position_major_level_id: @position_major_level.id)
      .includes(:department, :positions)
      .ordered
  end

  private

  def set_position_major_level
    @position_major_level = PositionMajorLevel.find(params[:id])
  end
end
