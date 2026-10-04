# frozen_string_literal: true

module MaapProposals
  # Structured apply-ready document for Title create proposals.
  class TitlePayload
    SCHEMA_VERSION = 1
    ATTR_KEYS = %w[
      external_title
      position_major_level_id
      department_id
      position_summary
      alternative_titles
    ].freeze

    def self.from_hash(raw)
      new(normalize(raw))
    end

    def self.blank_for_create(company:)
      major = default_position_major_level(company)
      from_hash(
        "external_title" => "New Title",
        "position_major_level_id" => major&.id,
        "department_id" => nil,
        "position_summary" => nil,
        "alternative_titles" => nil
      )
    end

    def self.default_position_major_level(company)
      Title.unarchived.for_company(company).group(:position_major_level_id).order(Arel.sql("COUNT(*) DESC")).limit(1)
           .pick(:position_major_level_id)
           .then { |id| PositionMajorLevel.find_by(id: id) } ||
        PositionMajorLevel.order(:id).first
    end

    def self.normalize(raw)
      hash = raw.deep_stringify_keys
      {
        "schema_version" => (hash["schema_version"].presence || SCHEMA_VERSION).to_i,
        "external_title" => hash["external_title"].to_s.strip,
        "position_major_level_id" => blank_to_nil_id(hash["position_major_level_id"]),
        "department_id" => blank_to_nil_id(hash["department_id"]),
        "position_summary" => blank_to_nil(hash["position_summary"]),
        "alternative_titles" => blank_to_nil(hash["alternative_titles"])
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

    ATTR_KEYS.each do |key|
      define_method(key) { @payload[key] }
    end

    def validate!(company:)
      errors = []
      errors << "external_title is required" if external_title.blank?
      errors << "position_major_level_id is required" if position_major_level_id.blank?

      if position_major_level_id.present? && PositionMajorLevel.find_by(id: position_major_level_id).nil?
        errors << "position_major_level_id is invalid"
      end

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
