# frozen_string_literal: true

module MaapProposals
  # Structured apply-ready document for Position create proposals.
  # title_id may be nil while a linked Title create proposal is still open.
  class PositionPayload
    SCHEMA_VERSION = 1
    ATTR_KEYS = %w[
      title_id
      title_proposal_id
      position_level_id
      position_level_hint
      position_summary
      assignment_links
    ].freeze

    def self.from_hash(raw)
      new(normalize(raw))
    end

    def self.blank_for_create
      from_hash(
        "title_id" => nil,
        "title_proposal_id" => nil,
        "position_level_id" => nil,
        "position_level_hint" => "1",
        "position_summary" => nil,
        "assignment_links" => []
      )
    end

    def self.normalize(raw)
      hash = raw.deep_stringify_keys
      {
        "schema_version" => (hash["schema_version"].presence || SCHEMA_VERSION).to_i,
        "title_id" => blank_to_nil_id(hash["title_id"]),
        "title_proposal_id" => blank_to_nil_id(hash["title_proposal_id"]),
        "position_level_id" => blank_to_nil_id(hash["position_level_id"]),
        "position_level_hint" => blank_to_nil(hash["position_level_hint"]) || "1",
        "position_summary" => blank_to_nil(hash["position_summary"]),
        "assignment_links" => normalize_assignment_links(hash["assignment_links"])
      }
    end

    def self.normalize_assignment_links(value)
      Array(value).filter_map do |row|
        next unless row.is_a?(Hash)

        link = row.deep_stringify_keys
        {
          "assignment_id" => blank_to_nil_id(link["assignment_id"]),
          "assignment_proposal_id" => blank_to_nil_id(link["assignment_proposal_id"]),
          "assignment_type" => link["assignment_type"].to_s.presence || "required",
          "energy_percentage" => link["energy_percentage"].presence&.to_i
        }
      end
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
      if title_id.blank? && title_proposal_id.blank?
        errors << "title_id or title_proposal_id is required"
      end

      if title_id.present?
        title = Title.find_by(id: title_id)
        if title.nil?
          errors << "title_id is invalid"
        elsif title.company_id != company.id
          errors << "title must belong to the company"
        end
      end

      if title_proposal_id.present?
        proposal = MaapProposal.find_by(id: title_proposal_id, organization: company)
        errors << "title_proposal_id is invalid" unless proposal&.title_create?
      end

      errors
    end

    def validate_for_apply!(company:)
      errors = validate!(company: company)
      errors << "title_id is required to apply" if title_id.blank?
      errors
    end
  end
end
