class AddHuddleInstructionIdToHuddles < ActiveRecord::Migration[8.0]
  def change
    add_reference :huddles, :huddle_instruction, null: true, foreign_key: true
  end
end
