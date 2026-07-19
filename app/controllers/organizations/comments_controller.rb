require 'set'

class Organizations::CommentsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_comment, only: [:show, :update, :destroy, :resolve, :unresolve]
  before_action :set_commentable, only: [:index, :create]

  after_action :verify_authorized

  def index
    authorize @commentable, :show?

    @commentable_behavior = Comments::CommentableBehavior.for(@commentable)
    @show_resolved = @commentable_behavior.allows_resolve? && params[:show_resolved] == 'true'

    root_comments_scope = Comment
      .for_commentable(@commentable)
      .root_comments
      .ordered
      .includes(:creator, :organization)

    @root_comments = if @commentable_behavior.allows_resolve?
      @show_resolved ? root_comments_scope : root_comments_scope.unresolved
    else
      root_comments_scope
    end

    @comments_by_parent = build_comments_tree(@root_comments, show_resolved: @show_resolved || !@commentable_behavior.allows_resolve?)
  end

  def show
    authorize @comment

    @comment_thread = [@comment] + @comment.descendants.to_a
    @comments_by_parent = build_comments_tree([@comment])
  end

  def create
    commentable_type = params[:commentable_type] || params[:comment][:commentable_type]
    commentable_id = params[:commentable_id] || params[:comment][:commentable_id]

    if commentable_type.present? && commentable_id.present?
      commentable_class = commentable_type.constantize
      @commentable = commentable_class.find(commentable_id)
    else
      raise ActiveRecord::RecordNotFound, "Commentable not found"
    end

    authorize @commentable, :show?
    @commentable_behavior = Comments::CommentableBehavior.for(@commentable)
    unless @commentable_behavior.allows_comments?
      root = Comments::CommentableBehavior.root_commentable_for(@commentable)
      redirect_to organization_comments_path(@organization, commentable_type: root.class.name, commentable_id: root.id),
                  alert: 'Comments can only be added to published observations.' and return
    end

    @comment = Comment.new
    @form = CommentForm.new(@comment)
    @form.current_person = current_person
    @form.commentable_type = commentable_type
    @form.commentable_id = commentable_id
    @form.organization_id = @organization.id

    if @form.validate(comment_params)
      @form.sync

      result = Comments::CreateService.call(
        comment: @form.model,
        commentable: @commentable,
        organization: @organization,
        creator: current_person
      )

      if result.ok?
        root_commentable = result.value.root_commentable
        redirect_params = { commentable_type: root_commentable.class.name, commentable_id: root_commentable.id }
        redirect_params[:show_resolved] = 'true' if params[:show_resolved] == 'true'
        redirect_to organization_comments_path(@organization, redirect_params),
                    notice: 'Comment was successfully created.'
      else
        errors = result.error.is_a?(Array) ? result.error : [result.error]
        errors.each { |error| @form.errors.add(:base, error) }
        prepare_index_for_render
        render :index, status: :unprocessable_entity
      end
    else
      prepare_index_for_render
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
      @form.sync

      result = Comments::UpdateService.call(
        comment: @comment,
        params: { body: @form.model.body }
      )

      if result.ok?
        root_commentable = @comment.root_commentable
        redirect_params = { commentable_type: root_commentable.class.name, commentable_id: root_commentable.id }
        redirect_params[:show_resolved] = 'true' if params[:show_resolved] == 'true'
        redirect_to organization_comments_path(@comment.organization, redirect_params),
                    notice: 'Comment was successfully updated.'
      else
        errors = result.error.is_a?(Array) ? result.error : [result.error]
        errors.each { |error| @form.errors.add(:base, error) }
        @commentable = @comment.root_commentable
        prepare_index_for_render
        render :index, status: :unprocessable_entity
      end
    else
      @commentable = @comment.root_commentable
      prepare_index_for_render
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @comment

    root_commentable = @comment.root_commentable
    result = Comments::DestroyService.call(comment: @comment)

    redirect_params = { commentable_type: root_commentable.class.name, commentable_id: root_commentable.id }
    redirect_params[:show_resolved] = 'true' if params[:show_resolved] == 'true'

    if result.ok?
      redirect_to organization_comments_path(@organization, redirect_params),
                  notice: 'Comment was successfully deleted.'
    else
      error_msg = result.error.is_a?(Array) ? result.error.join(', ') : result.error
      redirect_to organization_comments_path(@organization, redirect_params),
                  alert: "Failed to delete comment: #{error_msg}"
    end
  end

  def resolve
    authorize @comment, :resolve?

    result = Comments::ResolveService.call(comment: @comment)

    root_commentable = @comment.root_commentable
    redirect_params = { commentable_type: root_commentable.class.name, commentable_id: root_commentable.id }
    redirect_params[:show_resolved] = 'true' if params[:show_resolved] == 'true'

    if result.ok?
      redirect_to organization_comments_path(@comment.organization, redirect_params),
                  notice: 'Comment was successfully resolved.'
    else
      error_msg = result.error.is_a?(Array) ? result.error.join(', ') : result.error
      redirect_to organization_comments_path(@comment.organization, redirect_params),
                  alert: "Failed to resolve comment: #{error_msg}"
    end
  end

  def unresolve
    authorize @comment, :unresolve?

    result = Comments::UnresolveService.call(comment: @comment)

    root_commentable = @comment.root_commentable
    redirect_params = { commentable_type: root_commentable.class.name, commentable_id: root_commentable.id }
    redirect_params[:show_resolved] = 'true' if params[:show_resolved] == 'true'

    if result.ok?
      redirect_to organization_comments_path(@comment.organization, redirect_params),
                  notice: 'Comment was successfully unresolved.'
    else
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

  def prepare_index_for_render
    set_commentable unless @commentable
    @commentable = @commentable.root_commentable if @commentable.is_a?(Comment)
    @commentable_behavior = Comments::CommentableBehavior.for(@commentable)
    @show_resolved = @commentable_behavior.allows_resolve? && params[:show_resolved] == 'true'
    root_comments_scope = Comment
      .for_commentable(@commentable)
      .root_comments
      .ordered
      .includes(:creator, :organization)
    @root_comments = if @commentable_behavior.allows_resolve?
      @show_resolved ? root_comments_scope : root_comments_scope.unresolved
    else
      root_comments_scope
    end
    @comments_by_parent = build_comments_tree(@root_comments, show_resolved: @show_resolved || !@commentable_behavior.allows_resolve?)
  end

  def build_comments_tree(root_comments, show_resolved: false)
    comments_by_parent = {}
    comments_by_parent[nil] = root_comments.to_a

    all_loaded_comment_ids = Set.new(root_comments.map(&:id))
    current_level_ids = root_comments.map(&:id)

    while current_level_ids.any?
      child_comments_scope = Comment.where(commentable_type: 'Comment', commentable_id: current_level_ids)
                                   .ordered
                                   .includes(:creator, :organization)

      child_comments = show_resolved ? child_comments_scope.to_a : child_comments_scope.unresolved.to_a

      next_level_ids = []
      child_comments.each do |comment|
        parent_id = comment.commentable_id
        comments_by_parent[parent_id] ||= []
        comments_by_parent[parent_id] << comment

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
