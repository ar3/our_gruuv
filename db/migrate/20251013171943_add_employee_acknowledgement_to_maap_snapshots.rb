class AddEmployeeAcknowledgementToMaapSnapshots < ActiveRecord::Migration[8.0]
  def change
    # Rename request_info to manager_request_info
    rename_column :maap_snapshots, :request_info, :manager_request_info
    
    # Add employee acknowledgement fields
    add_column :maap_snapshots, :employee_acknowledged_at, :datetime
    add_column :maap_snapshots, :employee_acknowledgement_request_info, :jsonb, default: {}
    
    add_index :maap_snapshots, :employee_acknowledged_at
  end
end
