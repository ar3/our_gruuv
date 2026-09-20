# frozen_string_literal: true

# Attach / remove observation story images outside Reform (ActiveStorage + multipart).
module ObservationStoryImageParams
  extend ActiveSupport::Concern

  private

  # Returns false when uploads were rejected; true when applied or nothing to do.
  def apply_story_images!(observation)
    return true unless params[:observation].present?

    changed = false

    remove_ids = Array(params[:observation][:remove_story_image_ids]).map(&:presence).compact
    if remove_ids.any? && observation.story_images.attached?
      observation.story_images.attachments.where(id: remove_ids).find_each do |attachment|
        attachment.purge
        changed = true
      end
    end

    uploads = Array(params[:observation][:story_images]).reject(&:blank?)
    if uploads.any?
      remaining_slots = Observation::MAX_STORY_IMAGES - observation.story_images.count
      if remaining_slots <= 0
        observation.errors.add(:story_images, "can have at most #{Observation::MAX_STORY_IMAGES} images")
        return false
      end

      if uploads.size > remaining_slots
        observation.errors.add(
          :story_images,
          "can have at most #{Observation::MAX_STORY_IMAGES} images (#{remaining_slots} remaining)"
        )
        return false
      end

      uploads.each do |upload|
        content_type = upload.content_type.to_s
        unless content_type.in?(Observation::ALLOWED_STORY_IMAGE_CONTENT_TYPES)
          observation.errors.add(:story_images, 'must be JPEG, PNG, WebP, or HEIC')
          return false
        end
        if upload.size > Observation::MAX_STORY_IMAGE_BYTES
          observation.errors.add(
            :story_images,
            "must be under #{Observation::MAX_STORY_IMAGE_BYTES / 1.megabyte} MB each"
          )
          return false
        end
      end

      observation.story_images.attach(uploads)
      changed = true

      unless observation.valid?
        # Roll back bad attachments from this request
        uploads_count = uploads.size
        observation.story_images.attachments.last(uploads_count).each(&:purge)
        return false
      end
    end

    if changed && observation.published?
      observation.force_slack_notification_refresh = true
      observation.touch
    end

    true
  end
end
