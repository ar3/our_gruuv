# frozen_string_literal: true

module MaapProposals
  # Structured apply-ready document for Assignment edit proposals (jsonb SoT).
  class AssignmentPayload
    SCHEMA_VERSION = 1
    ATTR_KEYS = %w[
      title
      tagline
      required_activities
      handbook
      department_id
    ].freeze
    OUTCOME_KEYS = %w[
      id
      description
      outcome_type
    ].freeze

    def self.from_assignment(assignment)
      new(
        {
          "schema_version" => SCHEMA_VERSION,
          "title" => assignment.title.to_s,
          "tagline" => blank_to_nil(assignment.tagline),
          "required_activities" => blank_to_nil(assignment.required_activities),
          "handbook" => blank_to_nil(assignment.handbook),
          "department_id" => assignment.department_id,
          "outcomes" => assignment.assignment_outcomes.ordered.map { |outcome| outcome_hash(outcome) }
        }
      )
    end

    def self.from_hash(raw)
      new(normalize(raw))
    end

    def self.normalize(raw)
      hash = raw.deep_stringify_keys
      outcomes = Array(hash["outcomes"]).map { |row| normalize_outcome(row) }
      {
        "schema_version" => (hash["schema_version"].presence || SCHEMA_VERSION).to_i,
        "title" => hash["title"].to_s.strip,
        "tagline" => blank_to_nil(hash["tagline"]),
        "required_activities" => blank_to_nil(hash["required_activities"]),
        "handbook" => blank_to_nil(hash["handbook"]),
        "department_id" => blank_to_nil_id(hash["department_id"]),
        "outcomes" => outcomes
      }
    end

    def self.outcome_hash(outcome)
      {
        "id" => outcome.id,
        "description" => outcome.description.to_s.strip,
        "outcome_type" => outcome.outcome_type.to_s.presence || "quantitative"
      }
    end

    def self.normalize_outcome(row)
      hash = row.deep_stringify_keys
      {
        "id" => blank_to_nil_id(hash["id"]),
        "description" => hash["description"].to_s.strip,
        "outcome_type" => hash["outcome_type"].to_s.presence || "quantitative"
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

    def initialize(payload)
      @payload = self.class.normalize(payload)
    end

    def to_h
      @payload.deep_dup
    end

    def fingerprint
      {
        "title" => @payload["title"],
        "tagline" => @payload["tagline"],
        "required_activities" => @payload["required_activities"],
        "handbook" => @payload["handbook"],
        "department_id" => @payload["department_id"],
        "outcomes" => @payload["outcomes"]
      }
    end

    def same_as?(other)
      fingerprint == other.fingerprint
    end

    def title
      @payload["title"]
    end

    def tagline
      @payload["tagline"]
    end

    def required_activities
      @payload["required_activities"]
    end

    def handbook
      @payload["handbook"]
    end

    def department_id
      @payload["department_id"]
    end

    def outcomes
      @payload["outcomes"]
    end

    def validate!(company:)
      errors = []
      errors << "title is required" if title.blank?
      errors << "tagline is required" if tagline.blank?

      if department_id.present?
        dept = Department.find_by(id: department_id)
        if dept.nil?
          errors << "department_id is invalid"
        elsif dept.company_id != company.id
          errors << "department must belong to the company"
        end
      end

      outcomes.each_with_index do |outcome, index|
        errors << "outcome #{index + 1} description is required" if outcome["description"].blank?
        unless AssignmentOutcome::TYPES.include?(outcome["outcome_type"])
          errors << "outcome #{index + 1} type is invalid"
        end
      end

      errors
    end
  end
end
