# frozen_string_literal: true

class AddReviewMostRecentCheckInIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Narrow teammate + assignment first; supports IN (assignment_id) filters on review_most_recent / health-style queries.
    add_index :assignment_check_ins,
              %i[teammate_id assignment_id],
              name: "index_assignment_check_ins_on_teammate_and_assignment",
              algorithm: :concurrently,
              if_not_exists: true

    # Latest finalized position check-in per teammate (PositionCheckIn.latest_finalized_for).
    add_index :position_check_ins,
              %i[teammate_id official_check_in_completed_at],
              order: { official_check_in_completed_at: :desc },
              name: "index_position_check_ins_on_teammate_official_completed_desc",
              algorithm: :concurrently,
              if_not_exists: true

    # Position history "latest employee / manager completed" lookups scoped by teammate.
    add_index :position_check_ins,
              %i[teammate_id employee_completed_at],
              order: { employee_completed_at: :desc },
              name: "index_position_check_ins_on_teammate_employee_completed_desc",
              algorithm: :concurrently,
              if_not_exists: true

    add_index :position_check_ins,
              %i[teammate_id manager_completed_at],
              order: { manager_completed_at: :desc },
              name: "index_position_check_ins_on_teammate_manager_completed_desc",
              algorithm: :concurrently,
              if_not_exists: true

    # Aspiration check-ins: teammate + aspiration IN (...); existing 3-col index may not be ideal for all predicates.
    add_index :aspiration_check_ins,
              %i[teammate_id aspiration_id],
              name: "index_aspiration_check_ins_on_teammate_and_aspiration",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
