class CreatePageVisits < ActiveRecord::Migration[8.0]
  def change
    create_table :page_visits do |t|
      t.references :person, null: false, foreign_key: true
      t.text :url
      t.string :page_title
      t.text :user_agent
      t.datetime :visited_at

      t.timestamps
    end

    add_index :page_visits, :visited_at
    add_index :page_visits, [:person_id, :visited_at]
  end
end
