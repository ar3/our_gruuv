class AddFormParamsToMaapSnapshots < ActiveRecord::Migration[8.0]
  def change
    add_column :maap_snapshots, :form_params, :jsonb
  end
end
