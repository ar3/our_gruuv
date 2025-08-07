class Company < Organization
  # Companies are the top-level organizations
  validates :parent, absence: true

  # Third party object associations
  has_one :huddle_review_notification_channel_association, 
          class_name: 'ThirdPartyObjectAssociation',
          as: :associatable
  has_one :huddle_review_notification_channel, 
          through: :huddle_review_notification_channel_association,
          source: :third_party_object

  def display_name
    name
  end

  def huddle_review_notification_channel_id
    huddle_review_notification_channel&.third_party_id
  end

  def huddle_review_notification_channel_id=(channel_id)
    if channel_id.present?
      channel = third_party_objects.slack_channels.find_by(third_party_id: channel_id)
      if channel
        # Remove existing association
        huddle_review_notification_channel_association&.destroy
        
        # Create new association
        third_party_object_associations.create!(
          third_party_object: channel,
          association_type: 'huddle_review_notification_channel'
        )
      end
    else
      huddle_review_notification_channel_association&.destroy
    end
  end

  # Override the association to filter by association_type
  def huddle_review_notification_channel_association
    third_party_object_associations.where(association_type: 'huddle_review_notification_channel').first
  end
end 