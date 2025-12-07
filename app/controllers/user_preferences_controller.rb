class UserPreferencesController < ApplicationController
  before_action :authenticate_user!
  
  def update_layout
    authorize current_user_preferences, :update_layout?
    
    layout = params[:layout]
    unless %w[horizontal vertical].include?(layout)
      render json: { error: 'Invalid layout' }, status: :unprocessable_entity
      return
    end
    
    if current_user_preferences.update_preference(:layout, layout)
      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: 'Layout preference updated') }
        format.json { render json: { layout: layout } }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, alert: 'Failed to update layout preference') }
        format.json { render json: { error: 'Failed to update' }, status: :unprocessable_entity }
      end
    end
  end
  
  def update_vertical_nav
    authorize current_user_preferences, :update_vertical_nav?
    
    if params[:open].present?
      current_user_preferences.update_preference(:vertical_nav_open, params[:open] == 'true')
    end
    
    if params[:locked].present?
      locked = params[:locked] == 'true' || params[:locked] == true
      current_user_preferences.update_preference(:vertical_nav_locked, locked)
      
      # When locking, ensure nav is open
      if locked
        current_user_preferences.update_preference(:vertical_nav_open, true)
      end
    end
    
    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path, notice: 'Navigation preference updated') }
      format.json {
        render json: {
          open: current_user_preferences.vertical_nav_open?,
          locked: current_user_preferences.vertical_nav_locked?
        }
      }
    end
  end
  
  private
  
  def authenticate_user!
    redirect_to login_path unless current_person
  end
end

