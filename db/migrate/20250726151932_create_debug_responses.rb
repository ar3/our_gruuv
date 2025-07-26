class CreateDebugResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :debug_responses do |t|
      t.jsonb :request
      t.jsonb :response
      t.references :responseable, polymorphic: true, null: false
      t.text :notes

      t.timestamps
    end
  end
end
