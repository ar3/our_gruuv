# frozen_string_literal: true

class CreateMilestoneAwards < ActiveRecord::Migration[8.0]
  def change
    create_table :milestone_awards do |t|
      t.references :teammate, null: false, foreign_key: { to_table: :teammates }
      t.references :ability, null: false, foreign_key: true
      t.integer :official_milestone_level, null: false
      t.string :source, null: false
      t.references :certifying_teammate, null: false, foreign_key: { to_table: :teammates }
      t.references :organization, null: false, foreign_key: true
      t.references :ability_milestone_calibration_item, null: true, foreign_key: true

      t.text :certification_note
      t.string :privacy_level, null: false, default: "company"

      t.string :awarder_typed_name, null: false
      t.datetime :awarder_signed_at, null: false

      t.datetime :cosign_requested_at
      t.datetime :awarder_skipped_cosign_at

      t.references :cosigning_teammate, null: true, foreign_key: { to_table: :teammates }
      t.string :cosigner_typed_name
      t.text :cosigner_reason
      t.datetime :cosigner_signed_at

      t.datetime :moderator_requires_cosign_at
      t.references :moderator_teammate, null: true, foreign_key: { to_table: :teammates }

      t.timestamps
    end

    add_index :milestone_awards, :source
    add_index :milestone_awards, :awarder_skipped_cosign_at
    add_index :milestone_awards, :cosign_requested_at
    add_index :milestone_awards, :moderator_requires_cosign_at

    create_table :milestone_award_cosign_invites do |t|
      t.references :milestone_award, null: false, foreign_key: true
      t.references :invitee_teammate, null: false, foreign_key: { to_table: :teammates }
      t.datetime :declined_at
      t.text :decline_reason
      t.datetime :converted_to_feedback_at
      t.references :feedback_request, null: true, foreign_key: true

      t.timestamps
    end

    add_index :milestone_award_cosign_invites,
              [:milestone_award_id, :invitee_teammate_id],
              unique: true,
              name: "index_milestone_award_cosign_invites_uniqueness"

    add_reference :teammate_milestones, :milestone_award, foreign_key: true, null: true
  end
end
