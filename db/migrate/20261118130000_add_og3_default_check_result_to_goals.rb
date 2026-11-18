# frozen_string_literal: true

class AddOg3DefaultCheckResultToGoals < ActiveRecord::Migration[8.0]
  def change
    add_column :goals, :og3_default_check_result, :text
  end
end
