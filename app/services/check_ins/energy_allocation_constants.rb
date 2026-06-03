# frozen_string_literal: true

module CheckIns
  module EnergyAllocationConstants
    ALERT_SUCCESS = :success
    ALERT_WARNING = :warning
    ALERT_DANGER = :danger

    PALETTE = %w[
      #0d6efd #198754 #ffc107 #dc3545 #6f42c1 #fd7e14
      #20c997 #d63384 #0dcaf0 #6610f2 #adb5bd #495057
    ].freeze

    module_function

    def alert_band_for(total)
      return ALERT_SUCCESS if total == 100
      return ALERT_WARNING if total.between?(90, 110) && total != 100

      ALERT_DANGER
    end

    def assign_colors(assignment_ids)
      assignment_ids.each_with_index.to_h do |assignment_id, index|
        [assignment_id, PALETTE[index % PALETTE.length]]
      end
    end
  end
end
