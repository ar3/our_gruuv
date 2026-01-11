require 'set'

class Organizations::CommentsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_comment, only: [:show, :update, :resolve, :unresolve]
  before_action :set_commentable, only: [:index, :create]

  after_action :verify_authorized

  def index
    # Authorize based on the commentable object - if you can view it, you can view its comments
    authorize @commentable, :show?
    
    # Get all root comments for this commentable
    @root_comments = Comment
      .for_commentable(@commentable)
      .root_comments
      .ordered
      .includes(:creator, :organization)
    
    # Build nested structure for display
    @comments_by_parent = build_comments_tree(@root_comments)
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
    
    @comment = Comment.new(organization: @organization)
    @form = CommentForm.new(@comment)
    @form.current_person = current_person
    @form.commentable_type = commentable_type
    @form.commentable_id = commentable_id
    @form.organization_id = @organization.id

    if @form.validate(comment_params) && @form.save
      # Always redirect to the root commentable's comments page
      root_commentable = @form.model.root_commentable
      redirect_to organization_comments_path(@organization, commentable_type: root_commentable.class.name, commentable_id: root_commentable.id), 
                  notice: 'Comment was successfully created.'
    else
      # Re-fetch commentable for re-render
      set_commentable
      @root_comments = Comment
        .for_commentable(@commentable)
        .root_comments
        .ordered
        .includes(:creator, :organization)
      @comments_by_parent = build_comments_tree(@root_comments)
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

    if @form.validate(comment_params) && @form.save
      # Get root commentable for redirect
      root_commentable = @comment.root_commentable
      redirect_to organization_comments_path(@comment.organization, commentable_type: root_commentable.class.name, commentable_id: root_commentable.id), 
                  notice: 'Comment was successfully updated.'
    else
      # Get root commentable for re-render
      root_commentable = @comment.root_commentable
      @commentable = root_commentable
      @root_comments = Comment
        .for_commentable(root_commentable)
        .root_comments
        .ordered
        .includes(:creator, :organization)
      @comments_by_parent = build_comments_tree(@root_comments)
      render :index, status: :unprocessable_entity
    end
  end

  def resolve
    authorize @comment, :resolve?
    
    @comment.resolve!
    root_commentable = @comment.root_commentable
    redirect_to organization_comments_path(@comment.organization, commentable_type: root_commentable.class.name, commentable_id: root_commentable.id), 
                notice: 'Comment was successfully resolved.'
  end

  def unresolve
    authorize @comment, :unresolve?
    
    @comment.unresolve!
    root_commentable = @comment.root_commentable
    redirect_to organization_comments_path(@comment.organization, commentable_type: root_commentable.class.name, commentable_id: root_commentable.id), 
                notice: 'Comment was successfully unresolved.'
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

  def build_comments_tree(root_comments)
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
      child_comments = Comment.where(commentable_type: 'Comment', commentable_id: current_level_ids)
                             .ordered
                             .includes(:creator, :organization)
                             .to_a
      
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
