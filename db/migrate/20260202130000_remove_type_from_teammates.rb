# frozen_string_literal: true

class RemoveTypeFromTeammates < ActiveRecord::Migration[8.0]
  def change
    remove_column :teammates, :type, :string
  end
end
