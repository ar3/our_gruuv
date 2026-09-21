# frozen_string_literal: true

class CreateJobDescriptionAcknowledgements < ActiveRecord::Migration[8.0]
  def change
    create_table :job_description_acknowledgements do |t|
      t.references :company_teammate, null: false, foreign_key: { to_table: :teammates }
      t.references :organization, null: false, foreign_key: true
      t.references :employment_tenure, foreign_key: true
      t.references :position, foreign_key: true
      t.string :typed_name, null: false
      t.datetime :signed_at, null: false
      t.text :document_html, null: false
      t.jsonb :snapshot, null: false, default: {}

      t.timestamps
    end

    add_index :job_description_acknowledgements, [:company_teammate_id, :signed_at]
  end
end
