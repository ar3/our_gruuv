# frozen_string_literal: true

class AddEndCapToTitlesAndCreateTitlePaths < ActiveRecord::Migration[8.0]
  def change
    add_column :titles, :end_cap, :boolean, null: false, default: false

    create_table :title_paths do |t|
      t.references :from_title, null: false, foreign_key: { to_table: :titles }
      t.references :to_title, null: false, foreign_key: { to_table: :titles }
      t.string :path_type, null: false

      t.timestamps
    end

    add_index :title_paths, [:from_title_id, :to_title_id], unique: true, name: "index_title_paths_on_from_and_to"
    add_index :title_paths, :path_type
  end
end
