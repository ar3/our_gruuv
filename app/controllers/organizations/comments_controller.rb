require 'set'

class Organizations::CommentsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_comment, only: [:show, :update, :resolve, :unresolve]
  before_action :set_commentable, only: [:index, :create]

  after_action :verify_authorized

  def index
    # Authorize based on the commentable object - if you can view it, you can view its comments
    authorize @commentable, :show?
    
    # Get filter parameter for showing resolved comments
    @show_resolved = params[:show_resolved] == 'true'
    
    # Get all root comments for this commentable
    root_comments_scope = Comment
      .for_commentable(@commentable)
      .root_comments
      .ordered
      .includes(:creator, :organization)
    
    # Filter out resolved comments if toggle is off
    @root_comments = @show_resolved ? root_comments_scope : root_comments_scope.unresolved
    
    # Build nested structure for display
    @comments_by_parent = build_comments_tree(@root_comments, show_resolved: @show_resolved)
  end

  def show
    authorize @comment
    
    # Get all comments in this thread (comment and its descendants)
    @comment_thread = [@comment] + @comment.descendants.to_a
    @comments_by_parent = build_comments_tree([@comment])
  end

  def create
    # Set commentable from params FIRST (before authorization)
    commentable_type = params[:commentable_type] || params[:comment][:commentable_type]
    commentable_id = params[:commentable_id] || params[:comment][:commentable_id]
    
    if commentable_type.present? && commentable_id.present?
      commentable_class = commentable_type.constantize
      @commentable = commentable_class.find(commentable_id)
    else
      raise ActiveRecord::RecordNotFound, "Commentable not found"
    end
    
    # Authorize based on the commentable object - if you can view it, you can comment on it
    authorize @commentable, :show?
    
    @comment = Comment.new
    @form = CommentForm.new(@comment)
    @form.current_person = current_person
    @form.commentable_type = commentable_type
    @form.commentable_id = commentable_id
    @form.organization_id = @organization.id

    if @form.validate(comment_params)
      # Sync form data to model (but don't save yet - service will do that)
      @form.sync
      
      # Use service to create comment and handle Slack notifications
      result = Comments::CreateService.call(
        comment: @form.model,
        commentable: @commentable,
        organization: @organization,
        creator: current_person
      )
      
      if result.ok?
        # Always redirect to the root commentable's comments page
        root_commentable = result.value.root_commentable
        redirect_params = { commentable_type: root_commentable.class.name, commentable_id: root_commentable.id }
        redirect_params[:show_resolved] = 'true' if params[:show_resolved] == 'true'
        redirect_to organization_comments_path(@organization, redirect_params), 
                    notice: 'Comment was successfully created.'
      else
        # Add service errors to form
        errors = result.error.is_a?(Array) ? result.error : [result.error]
        errors.each { |error| @form.errors.add(:base, error) }
        # Re-fetch commentable for re-render
        set_commentable
        @show_resolved = params[:show_resolved] == 'true'
        root_comments_scope = Comment
          .for_commentable(@commentable)
          .root_comments
          .ordered
          .includes(:creator, :organization)
        @root_comments = @show_resolved ? root_comments_scope : root_comments_scope.unresolved
        @comments_by_parent = build_comments_tree(@root_comments, show_resolved: @show_resolved)
        render :index, status: :unprocessable_entity
      end
    else
      # Re-fetch commentable for re-render
      set_commentable
      @show_resolved = params[:show_resolved] == 'true'
      root_comments_scope = Comment
        .for_commentable(@commentable)
        .root_comments
        .ordered
        .includes(:creator, :organization)
      @root_comments = @show_resolved ? root_comments_scope : root_comments_scope.unresolved
      @comments_by_parent = build_comments_tree(@root_comments, show_resolved: @show_resolved)
      render :index, status: :unprocessable_entity
    end
  end

  def update
    authorize @comment
    
    @form = CommentForm.new(@comment)
    @form.current_person = current_person
    @form.organization_id = @comment.organization_id
    @form.commentable_type = @comment.commentable_type
    @form.commentable_id = @comment.commentable_id

    if @form.validate(comment_params)
      # Sync form data to model (but don't save yet - service will do that)
      @form.sync
      
      # Use service to update comment and handle Slack notifications
      result = Comments::UpdateService.call(
        comment: @comment,
        params: { body: @form.model.body }
      )
      
      if result.ok?
        # Get root commentable for redirect
        root_commentable = @comment.root_commentable
        redirect_params = { commentable_type: root_commentable.class.name, commentable_id: root_commentable.id }
        redirect_params[:show_resolved] = 'true' if params[:show_resolved] == 'true'
        redirect_to organization_comments_path(@comment.organization, redirect_params), 
                    notice: 'Comment was successfully updated.'
      else
        # Add service errors to form
        errors = result.error.is_a?(Array) ? result.error : [result.error]
        errors.each { |error| @form.errors.add(:base, error) }
        # Get root commentable for re-render
        root_commentable = @comment.root_commentable
        @commentable = root_commentable
        @show_resolved = params[:show_resolved] == 'true'
        root_comments_scope = Comment
          .for_commentable(root_commentable)
          .root_comments
          .ordered
          .includes(:creator, :organization)
        @root_comments = @show_resolved ? root_comments_scope : root_comments_scope.unresolved
        @comments_by_parent = build_comments_tree(@root_comments, show_resolved: @show_resolved)
        render :index, status: :unprocessable_entity
      end
    else
      # Get root commentable for re-render
      root_commentable = @comment.root_commentable
      @commentable = root_commentable
      @show_resolved = params[:show_resolved] == 'true'
      root_comments_scope = Comment
        .for_commentable(root_commentable)
        .root_comments
        .ordered
        .includes(:creator, :organization)
      @root_comments = @show_resolved ? root_comments_scope : root_comments_scope.unresolved
      @comments_by_parent = build_comments_tree(@root_comments, show_resolved: @show_resolved)
      render :index, status: :unprocessable_entity
    end
  end

  def resolve
    authorize @comment, :resolve?
    
    result = Comments::ResolveService.call(comment: @comment)
    
    if result.ok?
      root_commentable = @comment.root_commentable
      redirect_params = { commentable_type: root_commentable.class.name, commentable_id: root_commentable.id }
      redirect_params[:show_resolved] = 'true' if params[:show_resolved] == 'true'
      redirect_to organization_comments_path(@comment.organization, redirect_params), 
                  notice: 'Comment was successfully resolved.'
    else
      root_commentable = @comment.root_commentable
      redirect_params = { commentable_type: root_commentable.class.name, commentable_id: root_commentable.id }
      redirect_params[:show_resolved] = 'true' if params[:show_resolved] == 'true'
      error_msg = result.error.is_a?(Array) ? result.error.join(', ') : result.error
      redirect_to organization_comments_path(@comment.organization, redirect_params), 
                  alert: "Failed to resolve comment: #{error_msg}"
    end
  end

  def unresolve
    authorize @comment, :unresolve?
    
    result = Comments::UnresolveService.call(comment: @comment)
    
    if result.ok?
      root_commentable = @comment.root_commentable
      redirect_params = { commentable_type: root_commentable.class.name, commentable_id: root_commentable.id }
      redirect_params[:show_resolved] = 'true' if params[:show_resolved] == 'true'
      redirect_to organization_comments_path(@comment.organization, redirect_params), 
                  notice: 'Comment was successfully unresolved.'
    else
      root_commentable = @comment.root_commentable
      redirect_params = { commentable_type: root_commentable.class.name, commentable_id: root_commentable.id }
      redirect_params[:show_resolved] = 'true' if params[:show_resolved] == 'true'
      error_msg = result.error.is_a?(Array) ? result.error.join(', ') : result.error
      redirect_to organization_comments_path(@comment.organization, redirect_params), 
                  alert: "Failed to unresolve comment: #{error_msg}"
    end
  end

  private

  def set_comment
    @comment = Comment.find(params[:id])
  end

  def set_commentable
    commentable_type = params[:commentable_type]
    commentable_id = params[:commentable_id]
    
    return unless commentable_type.present? && commentable_id.present?
    
    commentable_class = commentable_type.constantize
    @commentable = commentable_class.find(commentable_id)
  end

  def comment_params
    params.require(:comment).permit(:body, :commentable_type, :commentable_id)
  end

  def build_comments_tree(root_comments, show_resolved: false)
    # Build a hash mapping parent comment id to array of child comments
    comments_by_parent = {}
    
    # Initialize with root comments (no parent)
    comments_by_parent[nil] = root_comments.to_a
    
    # Recursively load all nested comments
    all_loaded_comment_ids = Set.new(root_comments.map(&:id))
    current_level_ids = root_comments.map(&:id)
    
    # Keep loading nested comments until no more are found
    while current_level_ids.any?
      # Find direct children of current level
      child_comments_scope = Comment.where(commentable_type: 'Comment', commentable_id: current_level_ids)
                                   .ordered
                                   .includes(:creator, :organization)
      
      # Filter resolved comments if toggle is off
      child_comments = show_resolved ? child_comments_scope.to_a : child_comments_scope.unresolved.to_a
      
      # Group by parent and track IDs for next iteration
      next_level_ids = []
      child_comments.each do |comment|
        parent_id = comment.commentable_id
        comments_by_parent[parent_id] ||= []
        comments_by_parent[parent_id] << comment
        
        # Track this comment's ID for next iteration if we haven't seen it before
        unless all_loaded_comment_ids.include?(comment.id)
          all_loaded_comment_ids.add(comment.id)
          next_level_ids << comment.id
        end
      end
      
      current_level_ids = next_level_ids
    end
    
    comments_by_parent
  end
end
