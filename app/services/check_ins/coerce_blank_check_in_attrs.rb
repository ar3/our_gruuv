# frozen_string_literal: true

module CheckIns
  # Converts explicitly submitted blank values to nil for nullable check-in columns so
  # PATCH/POST can clear ratings, notes, and selects (bulk + 1-by-1). Only keys present in
  # +attrs+ are touched — missing keys are not interpreted as "clear".
  class CoerceBlankCheckInAttrs
    ASSIGNMENT_EMPLOYEE = %i[employee_rating employee_private_notes actual_energy_percentage employee_personal_alignment].freeze
    ASSIGNMENT_MANAGER = %i[manager_rating manager_private_notes].freeze
    ASPIRATION_EMPLOYEE = %i[employee_rating employee_private_notes].freeze
    ASPIRATION_MANAGER = %i[manager_rating manager_private_notes].freeze
    POSITION_EMPLOYEE = %i[employee_rating employee_private_notes].freeze
    POSITION_MANAGER = %i[manager_rating manager_private_notes].freeze

    class << self
      def for_assignment(attrs, view_mode:)
        return {} if attrs.blank?

        keys = case view_mode
        when :employee then ASSIGNMENT_EMPLOYEE
        when :manager then ASSIGNMENT_MANAGER
        else
          raise ArgumentError, "CheckIns::CoerceBlankCheckInAttrs.for_assignment: unexpected view_mode #{view_mode.inspect} (expected :employee or :manager)"
        end
        call(attrs, keys)
      end

      def for_aspiration(attrs, view_mode:)
        return {} if attrs.blank?

        keys = case view_mode
        when :employee then ASPIRATION_EMPLOYEE
        when :manager then ASPIRATION_MANAGER
        else
          raise ArgumentError, "CheckIns::CoerceBlankCheckInAttrs.for_aspiration: unexpected view_mode #{view_mode.inspect} (expected :employee or :manager)"
        end
        call(attrs, keys)
      end

      def for_position(attrs, view_mode:)
        return {} if attrs.blank?

        keys = case view_mode
        when :employee then POSITION_EMPLOYEE
        when :manager then POSITION_MANAGER
        else
          raise ArgumentError, "CheckIns::CoerceBlankCheckInAttrs.for_position: unexpected view_mode #{view_mode.inspect} (expected :employee or :manager)"
        end
        call(attrs, keys)
      end

      def call(attrs, nullable_keys)
        return {} if attrs.blank?

        h = attrs.to_h.with_indifferent_access
        nullable_keys.each do |sym|
          key = sym.to_s
          next unless h.key?(key)

          h[key] = nil if h[key].blank?
        end
        h.symbolize_keys
      end
    end
  end
end
