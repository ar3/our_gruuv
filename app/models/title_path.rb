# frozen_string_literal: true

class TitlePath < ApplicationRecord
  PATH_TYPES = {
    "natural_progression" => "Natural progression",
    "parallel_progression" => "Parallel progression",
    "switch_to_people_management" => "Switch to people management",
    "switch_to_individual_contribution" => "Switch to individual contribution",
    "switch_to_project_technical_leadership" => "Switch to project / technical leadership"
  }.freeze

  belongs_to :from_title, class_name: "Title"
  belongs_to :to_title, class_name: "Title"

  validates :path_type, presence: true, inclusion: { in: PATH_TYPES.keys }
  validates :to_title_id, uniqueness: { scope: :from_title_id }
  validate :no_self_linking
  validate :titles_in_same_company
  validate :from_title_not_end_cap
  validate :no_circular_paths

  def path_type_label
    PATH_TYPES[path_type] || path_type.to_s.humanize
  end

  private

  def no_self_linking
    return unless from_title_id.present? && to_title_id.present?
    return unless from_title_id == to_title_id

    errors.add(:base, "cannot link a title to itself")
  end

  def titles_in_same_company
    return unless from_title && to_title
    return if from_title.company_id == to_title.company_id

    errors.add(:base, "titles must belong to the same organization")
  end

  def from_title_not_end_cap
    return unless from_title&.end_cap?

    errors.add(:base, "end-cap titles cannot have outbound paths")
  end

  def no_circular_paths
    return unless from_title && to_title
    return if errors.any?

    if creates_cycle?
      errors.add(:base, "this path would create a circular reference")
    end
  end

  def creates_cycle?
    visited = Set.new
    queue = [to_title]

    while queue.any?
      current = queue.shift
      return true if current.id == from_title_id

      next if visited.include?(current.id)

      visited.add(current.id)
      current.outbound_title_paths.each do |path|
        next if path.id == id

        queue << path.to_title
      end
    end

    false
  end
end
