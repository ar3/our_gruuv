# frozen_string_literal: true

class CreateTalentDensityStances < ActiveRecord::Migration[8.0]
  def change
    create_table :talent_density_stances do |t|
      t.references :company_teammate, null: false, foreign_key: { to_table: :teammates },
                   index: { unique: true, name: "index_talent_density_stances_on_company_teammate_id" }
      t.references :company, null: false, foreign_key: { to_table: :organizations }
      t.string :stance
      t.text :notes

      t.timestamps
    end
  end
end
