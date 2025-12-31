class CreateChangeLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :change_logs do |t|
      t.date :launched_on
      t.string :image_url
      t.text :description
      t.string :change_type

      t.timestamps
    end
  end
end
