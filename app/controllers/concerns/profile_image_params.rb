# frozen_string_literal: true

# Handles optional profile_image upload / remove for Department and Team forms.
module ProfileImageParams
  extend ActiveSupport::Concern

  private

  # Mutates +attrs+ (deletes :remove_profile_image). Call before record.update(attrs).
  def apply_profile_image_param!(record, attrs)
    remove = ActiveModel::Type::Boolean.new.cast(attrs.delete(:remove_profile_image))
    return if attrs[:profile_image].present?
    return unless remove

    record.profile_image.purge if record.profile_image.attached?
  end
end
