class CreateUserPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :user_preferences do |t|
      t.references :person, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :preferences, default: {}

      t.timestamps
    end
  end
end
