# frozen_string_literal: true

class CreateTeammateNameAliases < ActiveRecord::Migration[8.0]
  def change
    create_table :teammate_name_aliases do |t|
      t.references :teammate, null: false, foreign_key: { to_table: :teammates }
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :source, null: false, default: "manual"
      t.references :created_by_company_teammate, null: true, foreign_key: { to_table: :teammates }

      t.timestamps
    end

    add_index :teammate_name_aliases, %i[teammate_id normalized_name], unique: true,
              name: "index_teammate_name_aliases_on_teammate_and_normalized_name"
    add_index :teammate_name_aliases, :normalized_name
  end
end
