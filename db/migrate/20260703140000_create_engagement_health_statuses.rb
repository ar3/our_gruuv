# frozen_string_literal: true

class CreateEngagementHealthStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :engagement_health_statuses do |t|
      t.references :teammate, null: false, foreign_key: { to_table: :teammates }
      t.references :organization, null: false, foreign_key: { to_table: :organizations }
      t.string :level, null: false # 'item' | 'category'
      t.string :category, null: false # ogo_given | ogo_received | goal_confidence | required_clarity | milestones
      t.string :entity_type
      t.bigint :entity_id
      t.string :status, null: false # healthy | at_risk | needs_attention
      t.jsonb :inputs, null: false, default: {}
      t.datetime :computed_at, null: false

      t.timestamps
    end

    add_index :engagement_health_statuses, [:teammate_id, :organization_id],
              name: "index_engagement_health_statuses_on_teammate_and_organization"
    add_index :engagement_health_statuses, [:teammate_id, :category, :level],
              name: "index_engagement_health_statuses_on_teammate_category_level"
  end
end
