class MakePrimaryFeelingNullable < ActiveRecord::Migration[8.0]
  def up
    change_column_null :observations, :primary_feeling, true
  end

  def down
    change_column_null :observations, :primary_feeling, false
  end
end