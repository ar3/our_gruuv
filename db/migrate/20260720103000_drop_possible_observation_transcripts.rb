# frozen_string_literal: true

class DropPossibleObservationTranscripts < ActiveRecord::Migration[8.0]
  def up
    # Detach historical consultations so subject FKs do not block the drop.
    # Kind ogo_search_transcript remains for Value Billing / Insights labels.
    execute <<~SQL.squish
      UPDATE og_consultations
      SET subject_type = NULL, subject_id = NULL
      WHERE subject_type = 'PossibleObservationTranscript'
    SQL

    execute <<~SQL.squish
      DELETE FROM active_storage_attachments
      WHERE record_type = 'PossibleObservationTranscript'
    SQL

    if foreign_key_exists?(:feedback_requests, :possible_observation_transcripts)
      remove_foreign_key :feedback_requests, :possible_observation_transcripts
    end
    if index_exists?(:feedback_requests, :possible_observation_transcript_id)
      remove_index :feedback_requests, :possible_observation_transcript_id
    end
    if column_exists?(:feedback_requests, :possible_observation_transcript_id)
      remove_column :feedback_requests, :possible_observation_transcript_id
    end

    drop_table :possible_observation_transcripts if table_exists?(:possible_observation_transcripts)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
