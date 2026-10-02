# frozen_string_literal: true

module MaapProposals
  # Replaces seat_titles from a SeatPayload (primary + additional).
  class SeatTitlesApplier
    def self.call(seat:, payload:)
      new(seat: seat, payload: payload).call
    end

    def initialize(seat:, payload:)
      @seat = seat
      @payload = payload
    end

    def call
      desired_ids = @payload.associated_title_ids
      return [] if desired_ids.empty?

      @seat.title_ids = desired_ids
      []
    end
  end
end
