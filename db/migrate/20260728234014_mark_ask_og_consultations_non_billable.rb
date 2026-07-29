# frozen_string_literal: true

class MarkAskOgConsultationsNonBillable < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE og_consultations
      SET billable = FALSE
      WHERE kind = 'ask_og' AND billable = TRUE
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE og_consultations
      SET billable = TRUE
      WHERE kind = 'ask_og' AND billable = FALSE
    SQL
  end
end
