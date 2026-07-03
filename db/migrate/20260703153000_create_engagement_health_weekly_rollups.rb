# frozen_string_literal: true

class CreateEngagementHealthWeeklyRollups < ActiveRecord::Migration[8.0]
  def change
    create_table :engagement_health_weekly_rollups do |t|
      t.references :teammate, null: false, foreign_key: { to_table: :teammates }
      t.references :organization, null: false, foreign_key: { to_table: :organizations }
      t.date :week_ending_on, null: false
      t.string :category, null: false
      t.string :status, null: false
      t.datetime :computed_at, null: false

      t.timestamps
    end

    add_index :engagement_health_weekly_rollups,
              %i[teammate_id organization_id week_ending_on category],
              unique: true,
              name: "index_eh_weekly_rollups_on_teammate_org_week_category"
    add_index :engagement_health_weekly_rollups,
              %i[organization_id week_ending_on],
              name: "index_eh_weekly_rollups_on_organization_and_week"
  end
end
