class CreateHuddleInstructions < ActiveRecord::Migration[8.0]
  def change
    create_table :huddle_instructions do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :instruction_alias
      t.string :slack_channel

      t.timestamps
    end
    
    add_index :huddle_instructions, [:organization_id, :instruction_alias], unique: true, name: 'index_huddle_instructions_on_org_and_instruction_alias'
  end
end
