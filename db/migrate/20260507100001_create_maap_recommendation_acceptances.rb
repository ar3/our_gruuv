# frozen_string_literal: true

class CreateMaapRecommendationAcceptances < ActiveRecord::Migration[8.0]
  def change
    create_table :maap_recommendation_acceptances do |t|
      t.references :maap_agent_run, null: false, foreign_key: true
      t.string :recommendation_id, null: false
      t.references :teammate, null: false, foreign_key: true

      t.timestamps
    end

    add_index :maap_recommendation_acceptances,
              %i[maap_agent_run_id recommendation_id],
              unique: true,
              name: 'index_maap_rec_acceptances_on_run_and_rec_id'
  end
end
