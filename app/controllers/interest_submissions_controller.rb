class InterestSubmissionsController < ApplicationController
  before_action :require_login, except: [:index, :new, :create, :show]
  
  def index
    authorize InterestSubmission
    
    # Store return_url and return_text from params for use in view
    @return_url = params[:return_url]
    @return_text = params[:return_text]
    
    # Use policy scope to get user's own submissions (or all if admin, or none if not logged in)
    interest_submissions_scope = policy_scope(InterestSubmission).includes(:person).recent
    
    # Paginate interest submissions if there are many (especially for admins viewing all)
    total_interest_count = interest_submissions_scope.count
    @interest_pagy = Pagy.new(count: total_interest_count, page: params[:interest_page] || 1, items: 25)
    @interest_submissions = interest_submissions_scope.limit(@interest_pagy.items).offset(@interest_pagy.offset)
    
    # Load change logs with pagination
    authorize ChangeLog
    change_logs_scope = policy_scope(ChangeLog).recent
    total_count = change_logs_scope.count
    @pagy = Pagy.new(count: total_count, page: params[:page] || 1, items: 25)
    @change_logs = change_logs_scope.limit(@pagy.items).offset(@pagy.offset)
    
    # Calculate spotlight stats (counts by change_type in past 90 days)
    past_90_days_logs = ChangeLog.in_past_90_days
    @spotlight_stats = {
      new_value: past_90_days_logs.by_change_type('new_value').count,
      major_enhancement: past_90_days_logs.by_change_type('major_enhancement').count,
      minor_enhancement: past_90_days_logs.by_change_type('minor_enhancement').count,
      bug_fix: past_90_days_logs.by_change_type('bug_fix').count
    }
    render layout: 'overlay'
  end
  
  def new
    # If not logged in, redirect to login with flash message
    unless current_person
      session[:return_to] = new_interest_submission_path
      redirect_to login_path, alert: 'To submit your ideas, login or create an account'
      return
    end
    
    @interest_submission = InterestSubmission.new
    @source_page = params[:source_page] || 'unknown'
    @return_url = params[:return_url] || root_path
    @interest_submission.source_page = @source_page
  end
  
  def create
    @interest_submission = InterestSubmission.new(interest_submission_params)
    
    # Set the person if logged in, otherwise create anonymous submission
    if current_person
      @interest_submission.person = current_person
    else
      # For anonymous submissions, we'll need to handle this differently
      # For now, redirect to login
      redirect_to root_path, alert: 'Please log in to submit your interest.'
      return
    end
    
    if @interest_submission.save
      redirect_to @interest_submission, notice: 'Thank you for your interest!'
    else
      @source_page = @interest_submission.source_page
      render :new, status: :unprocessable_entity
    end
  end
  
  def show
    @interest_submission = InterestSubmission.find(params[:id])
    authorize @interest_submission
  end
  
  private
  
  def require_login
    unless current_person
      redirect_to root_path, alert: 'Please log in to access this page.'
    end
  end
  
  
  def interest_submission_params
    params.require(:interest_submission).permit(:thing_interested_in, :why_interested, :current_solution, :source_page)
  end
end
