# frozen_string_literal: true

module MaapProposals
  # Structured apply-ready document for Seat edit proposals (jsonb SoT).
  class SeatPayload
    SCHEMA_VERSION = 1
    JOB_CLASSIFICATIONS = [
      "Salaried Exempt",
      "Salaried Non-Exempt",
      "Hourly",
      "Contractor",
      "Intern"
    ].freeze
    ATTR_KEYS = %w[
      title_id
      seat_needed_by
      job_classification
      team_id
      reports_to_seat_id
      reports
      seat_disclaimer
      work_environment
      physical_requirements
      travel
      why_needed
      why_now
      costs_risks
    ].freeze

    def self.from_seat(seat)
      new(
        {
          "schema_version" => SCHEMA_VERSION,
          "title_id" => seat.title_id,
          "seat_needed_by" => seat.seat_needed_by&.iso8601,
          "job_classification" => seat.job_classification.to_s,
          "team_id" => seat.team_id,
          "reports_to_seat_id" => seat.reports_to_seat_id,
          "reports" => blank_to_nil(seat.reports),
          "seat_disclaimer" => blank_to_nil(seat.seat_disclaimer),
          "work_environment" => blank_to_nil(seat.work_environment),
          "physical_requirements" => blank_to_nil(seat.physical_requirements),
          "travel" => blank_to_nil(seat.travel),
          "why_needed" => blank_to_nil(seat.why_needed),
          "why_now" => blank_to_nil(seat.why_now),
          "costs_risks" => blank_to_nil(seat.costs_risks)
        }
      )
    end

    def self.from_hash(raw)
      new(normalize(raw))
    end

    def self.empty
      from_hash({})
    end

    def self.normalize(raw)
      hash = raw.deep_stringify_keys
      {
        "schema_version" => (hash["schema_version"].presence || SCHEMA_VERSION).to_i,
        "title_id" => blank_to_nil_id(hash["title_id"]),
        "seat_needed_by" => normalize_date(hash["seat_needed_by"]),
        "job_classification" => hash["job_classification"].to_s.strip,
        "team_id" => blank_to_nil_id(hash["team_id"]),
        "reports_to_seat_id" => blank_to_nil_id(hash["reports_to_seat_id"]),
        "reports" => blank_to_nil(hash["reports"]),
        "seat_disclaimer" => blank_to_nil(hash["seat_disclaimer"]),
        "work_environment" => blank_to_nil(hash["work_environment"]),
        "physical_requirements" => blank_to_nil(hash["physical_requirements"]),
        "travel" => blank_to_nil(hash["travel"]),
        "why_needed" => blank_to_nil(hash["why_needed"]),
        "why_now" => blank_to_nil(hash["why_now"]),
        "costs_risks" => blank_to_nil(hash["costs_risks"])
      }
    end

    def self.blank_to_nil(value)
      str = value.to_s
      str.strip.empty? ? nil : str.strip
    end

    def self.blank_to_nil_id(value)
      return nil if value.nil? || value.to_s.strip.empty?

      value.to_i
    end

    def self.normalize_date(value)
      return nil if value.nil? || value.to_s.strip.empty?

      Date.parse(value.to_s).iso8601
    rescue ArgumentError, TypeError
      value.to_s.strip
    end

    def initialize(payload)
      @payload = self.class.normalize(payload)
    end

    def to_h
      @payload.deep_dup
    end

    def fingerprint
      @payload.slice(*ATTR_KEYS)
    end

    def same_as?(other)
      fingerprint == other.fingerprint
    end

    def seat_needed_by_date
      return nil if seat_needed_by.blank?

      Date.parse(seat_needed_by)
    rescue ArgumentError, TypeError
      nil
    end

    ATTR_KEYS.each do |key|
      define_method(key) { @payload[key] }
    end

    def validate!(company:, excluding_seat: nil)
      errors = []
      errors << "title_id is required" if title_id.blank?
      errors << "seat_needed_by is required" if seat_needed_by.blank?
      errors << "seat_needed_by is invalid" if seat_needed_by.present? && seat_needed_by_date.nil?
      errors << "job_classification is required" if job_classification.blank?
      if job_classification.present? && JOB_CLASSIFICATIONS.exclude?(job_classification)
        errors << "job_classification is invalid"
      end

      if title_id.present?
        title = Title.find_by(id: title_id)
        if title.nil?
          errors << "title_id is invalid"
        elsif title.company_id != company.id
          errors << "title must belong to the company"
        end
      end

      if team_id.present?
        team = Team.find_by(id: team_id)
        if team.nil?
          errors << "team_id is invalid"
        elsif team.company_id != company.id
          errors << "team must belong to the company"
        end
      end

      if reports_to_seat_id.present?
        manager_seat = Seat.find_by(id: reports_to_seat_id)
        if manager_seat.nil?
          errors << "reports_to_seat_id is invalid"
        elsif manager_seat.company_id != company.id
          errors << "reports_to seat must belong to the company"
        elsif excluding_seat && manager_seat.id == excluding_seat.id
          errors << "reports_to seat cannot be the same seat"
        end
      end

      errors
    end
  end
end
