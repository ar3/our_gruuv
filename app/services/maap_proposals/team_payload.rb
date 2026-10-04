# frozen_string_literal: true

module MaapProposals
  # Structured apply-ready document for Team create proposals.
  class TeamPayload
    SCHEMA_VERSION = 1
    ATTR_KEYS = %w[name department_id].freeze

    def self.from_hash(raw)
      new(normalize(raw))
    end

    def self.blank_for_create
      from_hash("name" => "New Team", "department_id" => nil)
    end

    def self.normalize(raw)
      hash = raw.deep_stringify_keys
      {
        "schema_version" => (hash["schema_version"].presence || SCHEMA_VERSION).to_i,
        "name" => hash["name"].to_s.strip,
        "department_id" => blank_to_nil_id(hash["department_id"])
      }
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

    ATTR_KEYS.each do |key|
      define_method(key) { @payload[key] }
    end

    def validate!(company:)
      errors = []
      errors << "name is required" if name.blank?

      if department_id.present?
        dept = Department.find_by(id: department_id)
        if dept.nil?
          errors << "department_id is invalid"
        elsif dept.company_id != company.id
          errors << "department must belong to the company"
        end
      end

      errors
    end
  end
end
