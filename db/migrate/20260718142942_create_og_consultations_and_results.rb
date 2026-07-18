# frozen_string_literal: true

class CreateOgConsultationsAndResults < ActiveRecord::Migration[8.0]
  def change
    create_table :og_consultations do |t|
      t.string :kind, null: false
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.bigint :organization_id, null: false
      t.bigint :triggered_by_teammate_id
      t.string :status, null: false, default: 'pending'
      t.boolean :billable, null: false, default: true
      t.string :prompt_version
      t.string :model_id
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message
      t.integer :units_total, null: false, default: 1
      t.integer :units_completed, null: false, default: 0
      t.string :result_type
      t.bigint :result_id

      t.timestamps
    end

    add_index :og_consultations, [:subject_type, :subject_id, :kind]
    add_index :og_consultations, [:organization_id, :status, :completed_at]
    add_index :og_consultations, [:kind, :status, :completed_at]
    add_index :og_consultations, :triggered_by_teammate_id
    add_index :og_consultations, [:result_type, :result_id]

    create_table :ability_clarity_results do |t|
      t.references :og_consultation, null: false, foreign_key: true, index: { unique: true }
      t.text :output_text
      t.string :clarity_rating
      t.timestamps
    end

    create_table :assignment_clarity_results do |t|
      t.references :og_consultation, null: false, foreign_key: true, index: { unique: true }
      t.text :output_text
      t.string :clarity_rating
      t.integer :clarity_score
      t.jsonb :clarity_recommendations, null: false, default: []
      t.text :consult_focus
      t.timestamps
    end

    create_table :position_clarity_results do |t|
      t.references :og_consultation, null: false, foreign_key: true, index: { unique: true }
      t.text :output_text
      t.string :clarity_rating
      t.timestamps
    end

    create_table :teammate_growth_results do |t|
      t.references :og_consultation, null: false, foreign_key: true, index: { unique: true }
      t.text :output_text
      t.string :clarity_rating
      t.timestamps
    end

    create_table :assignment_clarity_recommendation_acceptances do |t|
      t.references :assignment_clarity_result, null: false, foreign_key: true,
                   index: { name: 'index_assign_clarity_rec_acceptances_on_result_id' }
      t.string :recommendation_id, null: false
      t.bigint :teammate_id, null: false
      t.timestamps
    end

    add_index :assignment_clarity_recommendation_acceptances,
              [:assignment_clarity_result_id, :recommendation_id],
              unique: true,
              name: 'index_assign_clarity_rec_acceptances_on_result_and_rec'
    add_index :assignment_clarity_recommendation_acceptances, :teammate_id,
              name: 'index_assign_clarity_rec_acceptances_on_teammate_id'
  end
end
