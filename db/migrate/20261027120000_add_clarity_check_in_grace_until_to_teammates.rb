# frozen_string_literal: true

class AddClarityCheckInGraceUntilToTeammates < ActiveRecord::Migration[8.0]
  def change
    add_column :teammates, :clarity_check_in_grace_until, :date
  end
end
