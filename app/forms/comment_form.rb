class CommentForm < Reform::Form
  property :body
  property :commentable_type
  property :commentable_id
  property :organization_id

  validates :body, presence: true
  validates :commentable_type, presence: true
  validates :commentable_id, presence: true
  validates :organization_id, presence: true

  def save
    return false unless valid?

    # Let Reform sync the form data to the model first
    super

    # Set creator from current_person
    model.creator = current_person if model.new_record? || model.creator.nil?

    # Set commentable from type and id
    if commentable_type.present? && commentable_id.present?
      commentable_class = commentable_type.constantize
      model.commentable = commentable_class.find(commentable_id)
    end

    # Set organization
    if organization_id.present?
      model.organization = Organization.find(organization_id)
    end

    # Save the model
    model.save
  end

  # Helper method to get current person (passed from controller)
  def current_person
    @current_person
  end

  # Helper method to set current person
  def current_person=(person)
    @current_person = person
  end
end
