class AddMeasurementFieldsToAssignmentOutcomes < ActiveRecord::Migration[8.0]
  def change
    add_column :assignment_outcomes, :progress_report_url, :string
    add_column :assignment_outcomes, :management_relationship_filter, :string
    add_column :assignment_outcomes, :team_relationship_filter, :string
    add_column :assignment_outcomes, :consumer_assignment_filter, :string
  end
end
