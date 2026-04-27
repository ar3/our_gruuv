class AddPossibleObservationTranscriptToFeedbackRequests < ActiveRecord::Migration[8.0]
  def change
    add_reference :feedback_requests, :possible_observation_transcript, foreign_key: true, null: true
  end
end
