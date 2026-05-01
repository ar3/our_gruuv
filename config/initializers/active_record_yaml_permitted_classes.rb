# frozen_string_literal: true

# Rails 8 defaults `ActiveRecord.yaml_column_permitted_classes` to [Symbol] only.
# PaperTrail stores `versions.object_changes` as YAML that includes
# ActiveSupport::TimeWithZone for `updated_at` (and similar types). Without
# permitting those classes, Psych safe_load fails, PaperTrail::Version#changeset
# rescues to {}, and change-history UIs show blank "Fields" / summaries.
Rails.application.config.after_initialize do
  ActiveRecord.yaml_column_permitted_classes = (
    ActiveRecord.yaml_column_permitted_classes + [
      ActiveSupport::HashWithIndifferentAccess,
      ActiveSupport::TimeWithZone,
      ActiveSupport::TimeZone,
      Time,
      Date,
      DateTime,
      BigDecimal
    ]
  ).uniq
end
