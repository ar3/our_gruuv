class CreateObservations < ActiveRecord::Migration[8.0]
  def change
    create_table :observations do |t|
      t.references :observer, null: false, foreign_key: { to_table: :people }
      t.references :company, null: false, foreign_key: { to_table: :organizations }
      t.text :story, null: false
      t.integer :privacy_level, null: false, default: 0
      t.string :primary_feeling, null: false
      t.string :secondary_feeling
      t.datetime :observed_at
      t.string :custom_slug
      t.datetime :posted_to_slack_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :observations, :company_id, if_not_exists: true
    add_index :observations, :observer_id, if_not_exists: true
    add_index :observations, :observed_at, if_not_exists: true
    add_index :observations, :privacy_level, if_not_exists: true
    add_index :observations, :custom_slug, unique: true, if_not_exists: true
    add_index :observations, :deleted_at, if_not_exists: true
    add_index :observations, [:observed_at, :id], if_not_exists: true # For permalink lookups
  end
end
