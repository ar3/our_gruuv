# frozen_string_literal: true

module OgCandidateReview
  # When a candidate resolves observer == observee, default observer to the viewing teammate
  # (excavator logged in). Does not block intentional self-pairs if they already match the viewer.
  class DefaultObserverToViewer
    def self.apply(items, viewer:)
      new(viewer: viewer).apply(items)
    end

    def self.apply_one(item, viewer:)
      new(viewer: viewer).apply_one(item)
    end

    def initialize(viewer:)
      @viewer = viewer
    end

    def apply(items)
      Array(items).map { |item| apply_one(item) }
    end

    def apply_one(item)
      out = item.respond_to?(:with_indifferent_access) ? item.with_indifferent_access.deep_dup : item.deep_dup
      return out if @viewer.nil?

      rid = out[:responder_company_teammate_id].presence&.to_i
      sid = out[:subject_company_teammate_id].presence&.to_i
      return out if rid.blank? || sid.blank?
      return out unless rid == sid
      return out if rid == @viewer.id

      out[:responder_company_teammate_id] = @viewer.id
      out[:observer_unknown] = false
      out
    end
  end
end
