# frozen_string_literal: true

# Circular avatars for org groups (company / department / team).
# Company uses Organization#logo; departments and teams use #profile_image.
# Prefer this helper anywhere a group would otherwise show initials in a circle.
module GroupAvatarHelper
  def group_avatar(record, size: 48, alt: nil)
    attachment = group_avatar_attachment(record)
    if attachment
      image_tag url_for(attachment),
                class: 'rounded-circle',
                style: "width: #{size}px; height: #{size}px; object-fit: cover;",
                alt: alt.presence || group_avatar_alt(record)
    else
      organization_initials_circle(group_avatar_initials(record), size: size)
    end
  end

  def group_avatar_attachment(record)
    case record
    when Organization
      record.logo if record.logo.attached?
    when Department, Team
      record.profile_image if record.profile_image.attached?
    end
  end

  def group_avatar_initials(record)
    return '?' if record.blank?

    name = record.try(:name).presence ||
           record.try(:short_display_name).presence ||
           record.try(:display_name).presence ||
           'Org'
    initials = name.to_s.split(/\s+/).map { |part| part[0] }.compact.take(2).join.upcase
    initials.presence || 'O'
  end

  def group_avatar_alt(record)
    record.try(:name).presence || record.try(:display_name).presence || 'Group'
  end

  def organization_initials_circle(initials, size: 48)
    content_tag :div,
                class: 'bg-secondary rounded-circle d-flex align-items-center justify-content-center text-white',
                style: "width: #{size}px; height: #{size}px;" do
      content_tag :span, initials, class: 'fw-bold', style: "font-size: #{size * 0.4}px;"
    end
  end
end
