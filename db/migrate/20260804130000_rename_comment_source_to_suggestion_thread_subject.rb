class RenameCommentSourceToSuggestionThreadSubject < ActiveRecord::Migration[8.0]
  def change
    remove_index :comments, name: "index_comments_on_source", if_exists: true
    rename_column :comments, :source_type, :suggestion_thread_subject_type
    rename_column :comments, :source_id, :suggestion_thread_subject_id
    add_index :comments,
              [:suggestion_thread_subject_type, :suggestion_thread_subject_id],
              name: "index_comments_on_suggestion_thread_subject"
  end
end
