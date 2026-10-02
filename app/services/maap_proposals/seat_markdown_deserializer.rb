# frozen_string_literal: true

require "yaml"

module MaapProposals
  class SeatMarkdownDeserializer
    SECTION_HEADERS = {
      "reports" => :reports,
      "seat disclaimer" => :seat_disclaimer,
      "work environment" => :work_environment,
      "physical requirements" => :physical_requirements,
      "travel" => :travel,
      "why needed" => :why_needed,
      "why now" => :why_now,
      "costs / risks" => :costs_risks
    }.freeze

    def self.call(markdown:, organization:, seat: nil)
      new(markdown: markdown, organization: organization, seat: seat).call
    end

    def initialize(markdown:, organization:, seat:)
      @markdown = markdown.to_s
      @organization = organization
      @seat = seat
    end

    def call
      front_matter, body = split_front_matter(@markdown)
      meta = parse_front_matter(front_matter)
      identity_error = validate_identity(meta)
      return Result.err(identity_error) if identity_error

      sections = parse_sections(body)
      payload = SeatPayload.from_hash(
        {
          "schema_version" => meta["maap_proposal_schema_version"] || SeatPayload::SCHEMA_VERSION,
          "title_id" => meta["title_id"],
          "seat_needed_by" => meta["seat_needed_by"],
          "job_classification" => meta["job_classification"],
          "team_id" => meta["team_id"],
          "reports_to_seat_id" => meta["reports_to_seat_id"],
          "reports" => sections[:reports],
          "seat_disclaimer" => sections[:seat_disclaimer],
          "work_environment" => sections[:work_environment],
          "physical_requirements" => sections[:physical_requirements],
          "travel" => sections[:travel],
          "why_needed" => sections[:why_needed],
          "why_now" => sections[:why_now],
          "costs_risks" => sections[:costs_risks]
        }
      )

      errors = payload.validate!(company: @organization, excluding_seat: @seat)
      return Result.err(errors) if errors.any?

      kind = meta["kind"].presence || (@seat ? "edit" : "create")
      Result.ok(
        payload: payload,
        kind: kind,
        create_key: meta["create_key"].presence
      )
    rescue Psych::SyntaxError => e
      Result.err("Invalid YAML front matter: #{e.message}")
    end

    private

    def split_front_matter(text)
      if text.start_with?("---")
        parts = text.split(/^---\s*$/, 3)
        return [parts[1].to_s, parts[2].to_s] if parts.length >= 3
      end

      ["", text]
    end

    def parse_front_matter(raw)
      return {} if raw.strip.empty?

      parsed = YAML.safe_load(raw, permitted_classes: [Date, Time], aliases: false)
      (parsed || {}).deep_stringify_keys
    end

    def validate_identity(meta)
      type = meta["proposable_type"].to_s
      kind = meta["kind"].to_s.presence || (@seat ? "edit" : "create")
      id = meta["proposable_id"].to_i

      return "proposable_type must be Seat" if type.present? && type != "Seat"

      if kind == "create"
        return "create markdown must not include proposable_id" if id.positive?

        return nil
      end

      return "edit markdown requires a seat context" unless @seat
      return "proposable_id does not match this seat" if id.positive? && id != @seat.id

      nil
    end

    def parse_sections(body)
      sections = SECTION_HEADERS.values.index_with { nil }
      current = nil
      buffer = []

      flush = lambda do
        return if current.nil?

        sections[current] = buffer.join("\n").strip
        buffer = []
      end

      body.each_line do |line|
        header = line.strip.sub(/\A\#{1,3}\s+/, "").downcase
        if line.strip.match?(/\A\#{1,3}\s+/) && SECTION_HEADERS.key?(header)
          flush.call
          current = SECTION_HEADERS[header]
          next
        end

        buffer << line.rstrip if current
      end
      flush.call

      sections
    end
  end
end
