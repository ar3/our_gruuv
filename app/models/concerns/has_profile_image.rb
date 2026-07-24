# frozen_string_literal: true

module HasProfileImage
  extend ActiveSupport::Concern

  included do
    has_one_attached :profile_image
    validate :acceptable_profile_image, if: -> { profile_image.attached? }
  end

  private

  def acceptable_profile_image
    allowed = %w[image/png image/jpeg image/jpg image/webp image/gif]
    unless profile_image.content_type.in?(allowed)
      errors.add(:profile_image, 'must be a PNG, JPEG, WebP, or GIF')
    end
    if profile_image.byte_size > 5.megabytes
      errors.add(:profile_image, 'is too large (maximum is 5 MB)')
    end
  end
end
