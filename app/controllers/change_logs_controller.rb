class ChangeLogsController < ApplicationController
  before_action :set_change_log, only: [:show, :edit, :update, :destroy]
  after_action :verify_authorized, except: [:index, :show]

  def index
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
  end

  def show
    authorize @change_log
  end

  def new
    @change_log = ChangeLog.new
    authorize @change_log
  end

  def create
    @change_log = ChangeLog.new(change_log_params.except(:image))
    authorize @change_log

    # Handle image upload if present (takes precedence over image_url)
    if params[:change_log] && params[:change_log][:image].present?
      begin
        uploader = S3::ImageUploader.new
        @change_log.image_url = uploader.upload(params[:change_log][:image])
      rescue => e
        @change_log.errors.add(:image, "failed to upload: #{e.message}")
        render :new, status: :unprocessable_entity
        return
      end
    end

    if @change_log.save
      redirect_to @change_log, notice: 'Change log was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @change_log
  end

  def update
    authorize @change_log

    update_params = change_log_params.except(:image)
    
    # Handle image upload if present (takes precedence over image_url)
    if params[:change_log] && params[:change_log][:image].present?
      begin
        uploader = S3::ImageUploader.new
        update_params[:image_url] = uploader.upload(params[:change_log][:image])
      rescue => e
        @change_log.errors.add(:image, "failed to upload: #{e.message}")
        render :edit, status: :unprocessable_entity
        return
      end
    end

    if @change_log.update(update_params)
      redirect_to @change_log, notice: 'Change log was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @change_log
    @change_log.destroy
    redirect_to change_logs_path, notice: 'Change log was successfully deleted.'
  end

  private

  def set_change_log
    @change_log = ChangeLog.find(params[:id])
  end

  def change_log_params
    params.require(:change_log).permit(:launched_on, :image_url, :description, :change_type, :image)
  end
end

