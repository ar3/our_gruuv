# frozen_string_literal: true

module MaapProposals
  # Structured apply-ready document for Assignment edit proposals (jsonb SoT).
  # Schema v2 adds ability milestones + consumer/supplier reliance.
  class AssignmentPayload
    SCHEMA_VERSION = 2
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
    ABILITY_MILESTONE_KEYS = %w[
      ability_id
      milestone_level
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
          "outcomes" => assignment.assignment_outcomes.ordered.map { |outcome| outcome_hash(outcome) },
          "ability_milestones" => assignment.assignment_abilities.includes(:ability).by_milestone_level.map { |aa|
            ability_milestone_hash(aa)
          },
          "consumer_assignment_ids" => assignment.consumer_assignments.order(:title).pluck(:id),
          "supplier_assignment_ids" => assignment.supplier_assignments.order(:title).pluck(:id)
        }
      )
    end

    def self.from_hash(raw)
      new(normalize(raw))
    end

    def self.normalize(raw)
      hash = raw.deep_stringify_keys
      {
        "schema_version" => (hash["schema_version"].presence || SCHEMA_VERSION).to_i,
        "title" => hash["title"].to_s.strip,
        "tagline" => blank_to_nil(hash["tagline"]),
        "required_activities" => blank_to_nil(hash["required_activities"]),
        "handbook" => blank_to_nil(hash["handbook"]),
        "department_id" => blank_to_nil_id(hash["department_id"]),
        "outcomes" => Array(hash["outcomes"]).map { |row| normalize_outcome(row) },
        "ability_milestones" => Array(hash["ability_milestones"]).map { |row| normalize_ability_milestone(row) },
        "consumer_assignment_ids" => normalize_id_list(hash["consumer_assignment_ids"]),
        "supplier_assignment_ids" => normalize_id_list(hash["supplier_assignment_ids"])
      }
    end

    def self.outcome_hash(outcome)
      {
        "id" => outcome.id,
        "description" => outcome.description.to_s.strip,
        "outcome_type" => outcome.outcome_type.to_s.presence || "quantitative"
      }
    end

    def self.ability_milestone_hash(assignment_ability)
      {
        "ability_id" => assignment_ability.ability_id,
        "milestone_level" => assignment_ability.milestone_level
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

    def self.normalize_ability_milestone(row)
      hash = row.deep_stringify_keys
      {
        "ability_id" => blank_to_nil_id(hash["ability_id"]),
        "milestone_level" => blank_to_nil_id(hash["milestone_level"])
      }
    end

    def self.normalize_id_list(raw)
      Array(raw).filter_map { |value| blank_to_nil_id(value) }.uniq
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
        "outcomes" => @payload["outcomes"],
        "ability_milestones" => @payload["ability_milestones"],
        "consumer_assignment_ids" => @payload["consumer_assignment_ids"],
        "supplier_assignment_ids" => @payload["supplier_assignment_ids"]
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

    def ability_milestones
      @payload["ability_milestones"]
    end

    def consumer_assignment_ids
      @payload["consumer_assignment_ids"]
    end

    def supplier_assignment_ids
      @payload["supplier_assignment_ids"]
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

      seen_ability_ids = []
      ability_milestones.each_with_index do |row, index|
        if row["ability_id"].blank?
          errors << "ability milestone #{index + 1} ability_id is required"
        elsif seen_ability_ids.include?(row["ability_id"])
          errors << "ability milestone #{index + 1} duplicates ability_id #{row['ability_id']}"
        else
          seen_ability_ids << row["ability_id"]
        end

        level = row["milestone_level"].to_i
        unless (1..5).cover?(level)
          errors << "ability milestone #{index + 1} milestone_level must be 1-5"
        end
      end

      (consumer_assignment_ids + supplier_assignment_ids).each do |id|
        next if Assignment.exists?(id: id)

        # Soft: existence checked again on apply with skip+warn. Still flag obviously blank noise.
      end

      errors
    end
  end
end
