# frozen_string_literal: true

module Goals
  # OR-filter goals by one or more structural owner keys from Customize View:
  # "Company_123", "Department_456", "Team_789".
  # Department keys use RelatedToDepartmentQuery (same as the single-owner index path).
  class StructuralOwnerKeysFilter
    ALLOWED_PREFIXES = %w[Company Department Team].freeze

    def self.call(relation:, keys:)
      new(relation: relation, keys: keys).call
    end

    def self.normalize_keys(raw_keys)
      Array(raw_keys).flatten.map(&:to_s).map(&:strip).reject(&:blank?).uniq.select do |key|
        prefix, id = key.split("_", 2)
        ALLOWED_PREFIXES.include?(prefix) && id.present? && id.match?(/\A\d+\z/)
      end
    end

    def self.customized?(keys)
      normalize_keys(keys).size > 1
    end

    def initialize(relation:, keys:)
      @relation = relation
      @keys = self.class.normalize_keys(keys)
    end

    def call
      return @relation.none if @keys.empty?

      scopes = @keys.filter_map { |key| scope_for(key) }
      return @relation.none if scopes.empty?

      scopes.reduce { |combined, scope| combined.or(scope) }
    end

    private

    def scope_for(key)
      prefix, id = key.split("_", 2)
      case prefix
      when "Company"
        @relation.where(owner_type: "Organization", owner_id: id)
      when "Team"
        @relation.where(owner_type: "Team", owner_id: id)
      when "Department"
        department = Department.find_by(id: id)
        RelatedToDepartmentQuery.call(relation: @relation, department: department)
      end
    end
  end
end
