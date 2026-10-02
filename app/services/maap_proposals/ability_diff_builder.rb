# frozen_string_literal: true

module MaapProposals
  class AbilityDiffBuilder
    FieldDiff = Data.define(:key, :label, :before, :after, :html)

    SCALAR_FIELDS = [
      [:name, "Name"],
      [:description, "Description"],
      [:milestone_1_description, "Milestone 1"],
      [:milestone_2_description, "Milestone 2"],
      [:milestone_3_description, "Milestone 3"],
      [:milestone_4_description, "Milestone 4"],
      [:milestone_5_description, "Milestone 5"]
    ].freeze

    def self.call(before: nil, after: nil, ability: nil, payload: nil)
      before_payload = coerce_before(before: before, ability: ability)
      after_payload = coerce_after(after: after, payload: payload)
      new(before: before_payload, after: after_payload).call
    end

    def self.coerce_before(before:, ability:)
      return AbilityPayload.from_ability(ability) if before.nil? && ability
      return before if before.is_a?(AbilityPayload)
      return AbilityPayload.from_hash(before) if before.present?

      raise ArgumentError, "before or ability is required"
    end
    private_class_method :coerce_before

    def self.coerce_after(after:, payload:)
      source = after || payload
      raise ArgumentError, "after or payload is required" if source.nil?
      return source if source.is_a?(AbilityPayload)

      AbilityPayload.from_hash(source)
    end
    private_class_method :coerce_after

    def initialize(before:, after:)
      @before = before
      @after = after
    end

    def call
      diffs = []

      SCALAR_FIELDS.each do |key, label|
        before_value = normalize(@before.public_send(key))
        after_value = normalize(@after.public_send(key))
        next if before_value == after_value

        diffs << build_field(key, label, before_value, after_value)
      end

      before_dept = department_label(@before.department_id)
      after_dept = department_label(@after.department_id)
      if before_dept != after_dept
        diffs << build_field(:department, "Department", before_dept, after_dept)
      end

      diffs
    end

    private

    def build_field(key, label, before, after)
      html = Diffy::Diff.new(
        before,
        after,
        include_plus_and_minus_in_html: true,
        allow_empty_diff: false
      ).to_s(:html)

      FieldDiff.new(key: key, label: label, before: before, after: after, html: html)
    end

    def normalize(value)
      value.nil? ? "" : value.to_s
    end

    def department_label(department_id)
      return "" if department_id.blank?

      Department.find_by(id: department_id)&.name.to_s
    end
  end
end
