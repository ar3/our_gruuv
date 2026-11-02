# frozen_string_literal: true

class CreateSlackPogoAutoRefresh < ActiveRecord::Migration[8.0]
  def change
    add_column :teammates, :slack_pogo_auto_refresh_hub_enabled, :boolean, null: false, default: false

    create_table :slack_pogo_auto_refresh_enrollments do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :runner_company_teammate, null: false, foreign_key: { to_table: :teammates },
                   index: { name: "idx_slack_pogo_auto_refresh_on_runner" }
      t.references :subject_company_teammate, null: false, foreign_key: { to_table: :teammates },
                   index: { name: "idx_slack_pogo_auto_refresh_on_subject" }
      t.string :source, null: false, default: "manual"
      t.datetime :last_refreshed_at

      t.timestamps
    end

    add_index :slack_pogo_auto_refresh_enrollments,
              %i[runner_company_teammate_id subject_company_teammate_id],
              unique: true,
              name: "idx_slack_pogo_auto_refresh_enrollments_uniq"
    add_index :slack_pogo_auto_refresh_enrollments, :last_refreshed_at
    add_index :slack_pogo_auto_refresh_enrollments, :source
  end
end
