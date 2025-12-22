class AddArchivedAtToPromptQuestions < ActiveRecord::Migration[8.0]
  def change
    add_column :prompt_questions, :archived_at, :datetime
    add_index :prompt_questions, :archived_at
  end
end
