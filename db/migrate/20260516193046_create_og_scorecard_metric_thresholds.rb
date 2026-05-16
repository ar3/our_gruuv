class CreateOgScorecardMetricThresholds < ActiveRecord::Migration[8.0]
  def change
    create_table :og_scorecard_metric_thresholds do |t|
      t.references :company, null: false, foreign_key: { to_table: :organizations }
      t.string :metric_key
      t.string :threshold_mode
      t.decimal :yellow_threshold
      t.decimal :green_threshold

      t.timestamps
    end

    add_index :og_scorecard_metric_thresholds, %i[company_id metric_key], unique: true, name: 'idx_og_scorecard_thresholds_company_metric'
  end
end
