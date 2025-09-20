class InterestSubmissionsController < ApplicationController
  layout 'authenticated-v2-0'
  before_action :require_login, except: [:new, :create, :show]
  before_action :ensure_admin!, only: [:index]
  
  def index
    @interest_submissions = InterestSubmission.includes(:person).recent
  end
  
  def new
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
  end
  
  private
  
  def require_login
    unless current_person
      redirect_to root_path, alert: 'Please log in to access this page.'
    end
  end
  
  def ensure_admin!
    unless current_person&.og_admin?
      redirect_to root_path, alert: 'You must be an administrator to access this page.'
    end
  end
  
  def interest_submission_params
    params.require(:interest_submission).permit(:thing_interested_in, :why_interested, :current_solution, :source_page)
  end
end
