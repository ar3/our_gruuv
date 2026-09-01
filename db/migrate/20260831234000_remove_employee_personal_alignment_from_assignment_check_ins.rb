# frozen_string_literal: true

class RemoveEmployeePersonalAlignmentFromAssignmentCheckIns < ActiveRecord::Migration[8.0]
  def up
    say_with_time "Backfilling any remaining check-in alignments into survey responses" do
      execute <<~SQL.squish
        INSERT INTO assignment_survey_responses (
          assignment_id,
          assignment_source,
          snapshot_title,
          snapshot_tagline,
          snapshot_required_activities,
          snapshot_outcomes,
          personal_alignment,
          teammate_id,
          organization_id,
          submitted_at,
          source_assignment_check_in_id,
          created_at,
          updated_at
        )
        SELECT
          ci.assignment_id,
          'active',
          a.title,
          a.tagline,
          a.required_activities,
          '[]'::jsonb,
          ci.employee_personal_alignment,
          ci.teammate_id,
          a.company_id,
          ci.employee_completed_at,
          ci.id,
          NOW(),
          NOW()
        FROM assignment_check_ins ci
        INNER JOIN assignments a ON a.id = ci.assignment_id
        WHERE ci.employee_personal_alignment IS NOT NULL
          AND ci.employee_completed_at IS NOT NULL
          AND NOT EXISTS (
            SELECT 1
            FROM assignment_survey_responses r
            WHERE r.source_assignment_check_in_id = ci.id
          )
      SQL
    end

    remove_column :assignment_check_ins, :employee_personal_alignment, :string
  end

  def down
    add_column :assignment_check_ins, :employee_personal_alignment, :string
    say "Down migration restores the column only; values are not restored from survey responses."
  end
end
