# frozen_string_literal: true

module MaapProposals
  class SeatMarkdownSerializer
    def self.call(payload:, seat: nil, kind: nil, create_key: nil)
      new(payload: payload, seat: seat, kind: kind, create_key: create_key).call
    end

    def initialize(payload:, seat:, kind:, create_key:)
      @seat = seat
      @payload = payload.is_a?(SeatPayload) ? payload : SeatPayload.from_hash(payload)
      @kind = (kind.presence || (@seat ? "edit" : "create")).to_s
      @create_key = create_key
    end

    def call
      [front_matter, body].join("\n")
    end

    private

    def front_matter
      lines = ["---"]
      lines << "maap_proposal_schema_version: #{SeatPayload::SCHEMA_VERSION}"
      lines << "proposable_type: Seat"
      lines << "kind: #{@kind}"
      if @kind == "create"
        lines << "create_key: #{yaml_scalar(@create_key)}"
      else
        lines << "proposable_id: #{@seat.id}"
      end
      lines << "title_id: #{yaml_scalar(@payload.title_id)}"
      lines << "seat_needed_by: #{yaml_scalar(@payload.seat_needed_by)}"
      lines << "job_classification: #{yaml_scalar(@payload.job_classification)}"
      lines << "team_id: #{yaml_scalar(@payload.team_id)}"
      lines << "reports_to_seat_id: #{yaml_scalar(@payload.reports_to_seat_id)}"
      lines << "---"
      lines.join("\n")
    end

    def body
      parts = []
      [
        ["Reports", @payload.reports],
        ["Seat disclaimer", @payload.seat_disclaimer],
        ["Work environment", @payload.work_environment],
        ["Physical requirements", @payload.physical_requirements],
        ["Travel", @payload.travel],
        ["Why needed", @payload.why_needed],
        ["Why now", @payload.why_now],
        ["Costs / risks", @payload.costs_risks]
      ].each do |heading, value|
        parts << "## #{heading}"
        parts << ""
        parts << value.to_s
        parts << ""
      end
      parts.join("\n").rstrip + "\n"
    end

    def yaml_scalar(value)
      value.nil? || value.to_s.strip.empty? ? "" : value.to_s
    end
  end
end
