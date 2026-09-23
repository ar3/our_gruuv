# frozen_string_literal: true

class AddPeriodToTalentDensityStances < ActiveRecord::Migration[8.0]
  def up
    add_reference :talent_density_stances, :stance_set_by, foreign_key: { to_table: :people }, null: true
    add_column :talent_density_stances, :stance_set_at, :datetime
    add_column :talent_density_stances, :period_month, :date

    # Existing rows become the Confidential Talent Reflection for the month they were last updated.
    execute <<~SQL.squish
      UPDATE talent_density_stances
      SET period_month = date_trunc('month', updated_at)::date
    SQL

    change_column_null :talent_density_stances, :period_month, false

    remove_index :talent_density_stances,
                 name: "index_talent_density_stances_on_company_teammate_id"
    add_index :talent_density_stances,
              [:company_teammate_id, :period_month],
              unique: true,
              name: "index_talent_density_stances_on_teammate_and_period"
  end

  def down
    remove_index :talent_density_stances,
                 name: "index_talent_density_stances_on_teammate_and_period"
    add_index :talent_density_stances,
              :company_teammate_id,
              unique: true,
              name: "index_talent_density_stances_on_company_teammate_id"

    remove_column :talent_density_stances, :period_month
    remove_column :talent_density_stances, :stance_set_at
    remove_reference :talent_density_stances, :stance_set_by, foreign_key: { to_table: :people }
  end
end
