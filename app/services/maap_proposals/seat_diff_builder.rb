# frozen_string_literal: true

module MaapProposals
  class SeatDiffBuilder
    FieldDiff = Data.define(:key, :label, :before, :after, :html)

    SCALAR_FIELDS = [
      [:seat_needed_by, "Needed by"],
      [:job_classification, "Job classification"],
      [:reports, "Direct reports"],
      [:seat_disclaimer, "Seat disclaimer"],
      [:work_environment, "Work environment"],
      [:physical_requirements, "Physical requirements"],
      [:travel, "Travel"],
      [:why_needed, "Why needed"],
      [:why_now, "Why now"],
      [:costs_risks, "Costs / risks"]
    ].freeze

    def self.call(before: nil, after: nil, seat: nil, payload: nil)
      before_payload = coerce_before(before: before, seat: seat)
      after_payload = coerce_after(after: after, payload: payload)
      new(before: before_payload, after: after_payload).call
    end

    def self.coerce_before(before:, seat:)
      return SeatPayload.empty if before == :empty
      return SeatPayload.from_seat(seat) if before.nil? && seat
      return before if before.is_a?(SeatPayload)
      return SeatPayload.from_hash(before) if before.present?

      raise ArgumentError, "before or seat is required"
    end
    private_class_method :coerce_before

    def self.coerce_after(after:, payload:)
      source = after || payload
      raise ArgumentError, "after or payload is required" if source.nil?
      return source if source.is_a?(SeatPayload)

      SeatPayload.from_hash(source)
    end
    private_class_method :coerce_after

    def initialize(before:, after:)
      @before = before
      @after = after
    end

    def call
      diffs = []

      before_title = title_label(@before.title_id)
      after_title = title_label(@after.title_id)
      if before_title != after_title
        diffs << build_field(:title, "Primary title", before_title, after_title)
      end

      SCALAR_FIELDS.each do |key, label|
        before_value = normalize(@before.public_send(key))
        after_value = normalize(@after.public_send(key))
        next if before_value == after_value

        diffs << build_field(key, label, before_value, after_value)
      end

      before_team = team_label(@before.team_id)
      after_team = team_label(@after.team_id)
      if before_team != after_team
        diffs << build_field(:team, "Team", before_team, after_team)
      end

      before_reports_to = seat_label(@before.reports_to_seat_id)
      after_reports_to = seat_label(@after.reports_to_seat_id)
      if before_reports_to != after_reports_to
        diffs << build_field(:reports_to_seat, "Reports to seat", before_reports_to, after_reports_to)
      end

      diffs
    end

    private

    def build_field(key, label, before, after)
      html = Diffy::Diff.new(
        before,
        after,
        include_plus_and_minus_in_html: true,
        allow_empty_diff: false
      ).to_s(:html)

      FieldDiff.new(key: key, label: label, before: before, after: after, html: html)
    end

    def normalize(value)
      value.nil? ? "" : value.to_s
    end

    def title_label(title_id)
      return "" if title_id.blank?

      Title.find_by(id: title_id)&.external_title.to_s
    end

    def team_label(team_id)
      return "" if team_id.blank?

      Team.find_by(id: team_id)&.display_name.to_s
    end

    def seat_label(seat_id)
      return "" if seat_id.blank?

      Seat.find_by(id: seat_id)&.display_name.to_s
    end
  end
end
