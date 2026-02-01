class Company < Organization
  # Companies are the top-level organizations
  # Note: parent hierarchy has been removed - companies are standalone top-level organizations

  # Third party object associations
  has_one :huddle_review_notification_channel_association, 
          -> { where(association_type: 'huddle_review_notification_channel') },
          class_name: 'ThirdPartyObjectAssociation',
          as: :associatable
  has_one :huddle_review_notification_channel, 
          through: :huddle_review_notification_channel_association,
          source: :third_party_object
  
  has_one :maap_object_comment_channel_association,
          -> { where(association_type: 'maap_object_comment_channel') },
          class_name: 'ThirdPartyObjectAssociation',
          as: :associatable
  has_one :maap_object_comment_channel,
          through: :maap_object_comment_channel_association,
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

  def maap_object_comment_channel_id
    maap_object_comment_channel&.third_party_id
  end

  def maap_object_comment_channel_id=(channel_id)
    if channel_id.present?
      channel = third_party_objects.slack_channels.find_by(third_party_id: channel_id)
      if channel
        # Remove existing association
        maap_object_comment_channel_association&.destroy
        
        # Create new association
        third_party_object_associations.create!(
          third_party_object: channel,
          association_type: 'maap_object_comment_channel'
        )
      end
    else
      maap_object_comment_channel_association&.destroy
    end
  end

  has_many :company_label_preferences, dependent: :destroy

  def label_for(key, default = nil)
    preference = company_label_preferences.find_by(label_key: key.to_s)
    if preference&.label_value.present?
      preference.label_value
    elsif default.present?
      default
    else
      key.to_s.titleize
    end
  end
end 