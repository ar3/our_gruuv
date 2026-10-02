# frozen_string_literal: true

module MaapProposals
  # Structured apply-ready document for Ability edit proposals (jsonb SoT).
  class AbilityPayload
    SCHEMA_VERSION = 1
    ATTR_KEYS = %w[
      name
      description
      department_id
      milestone_1_description
      milestone_2_description
      milestone_3_description
      milestone_4_description
      milestone_5_description
    ].freeze
    MILESTONE_KEYS = (1..5).map { |n| "milestone_#{n}_description" }.freeze

    def self.from_ability(ability)
      new(
        {
          "schema_version" => SCHEMA_VERSION,
          "name" => ability.name.to_s,
          "description" => blank_to_nil(ability.description),
          "department_id" => ability.department_id,
          "milestone_1_description" => blank_to_nil(ability.milestone_1_description),
          "milestone_2_description" => blank_to_nil(ability.milestone_2_description),
          "milestone_3_description" => blank_to_nil(ability.milestone_3_description),
          "milestone_4_description" => blank_to_nil(ability.milestone_4_description),
          "milestone_5_description" => blank_to_nil(ability.milestone_5_description)
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
        "name" => hash["name"].to_s.strip,
        "description" => blank_to_nil(hash["description"]),
        "department_id" => blank_to_nil_id(hash["department_id"]),
        "milestone_1_description" => blank_to_nil(hash["milestone_1_description"]),
        "milestone_2_description" => blank_to_nil(hash["milestone_2_description"]),
        "milestone_3_description" => blank_to_nil(hash["milestone_3_description"]),
        "milestone_4_description" => blank_to_nil(hash["milestone_4_description"]),
        "milestone_5_description" => blank_to_nil(hash["milestone_5_description"])
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
      @payload.slice(*ATTR_KEYS)
    end

    def same_as?(other)
      fingerprint == other.fingerprint
    end

    ATTR_KEYS.each do |key|
      define_method(key) { @payload[key] }
    end

    def validate!(company:)
      errors = []
      errors << "name is required" if name.blank?
      errors << "description is required" if description.blank?

      if department_id.present?
        dept = Department.find_by(id: department_id)
        if dept.nil?
          errors << "department_id is invalid"
        elsif dept.company_id != company.id
          errors << "department must belong to the company"
        end
      end

      if MILESTONE_KEYS.none? { |key| @payload[key].present? }
        errors << "at least one milestone description is required"
      end

      errors
    end
  end
end
