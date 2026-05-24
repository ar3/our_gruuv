# frozen_string_literal: true

class CytoscapeGraphLayout < ApplicationRecord
  GRAPH_KINDS = %w[full_network accountability_flow position_reliance].freeze

  belongs_to :layoutable, polymorphic: true

  validates :graph_kind, presence: true, inclusion: { in: GRAPH_KINDS }
  validates :layoutable_id, uniqueness: { scope: %i[layoutable_type graph_kind] }
  validate :positions_shape

  def self.for_layoutable(layoutable, graph_kind:)
    find_by(layoutable: layoutable, graph_kind: graph_kind)
  end

  def self.upsert_for!(layoutable:, graph_kind:, positions:, node_fingerprint:)
    record = find_or_initialize_by(layoutable: layoutable, graph_kind: graph_kind)
    record.assign_attributes(positions: positions, node_fingerprint: node_fingerprint)
    record.save!
    record
  end

  private

  def positions_shape
    return if positions.blank?
    return if positions.is_a?(Hash) && positions.values.all? { |coords| valid_coords?(coords) }

    errors.add(:positions, "must be a hash of node id => { x, y } coordinates")
  end

  def valid_coords?(coords)
    coords.is_a?(Hash) &&
      coords.key?("x") && coords.key?("y") &&
      coords["x"].is_a?(Numeric) && coords["y"].is_a?(Numeric)
  end
end
