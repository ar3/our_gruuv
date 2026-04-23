class UserPreferencesController < ApplicationController
  before_action :authenticate_user!

  VERTICAL_NAV_MODES = %w[locked_open closed_unless_opened].freeze
  
  def update_layout
    authorize current_user_preferences, :update_layout?
    
    layout = params[:layout]
    unless %w[horizontal vertical no_nav].include?(layout)
      render json: { error: 'Invalid layout' }, status: :unprocessable_entity
      return
    end
    
    if current_user_preferences.update_preference(:layout, layout)
      if layout == "no_nav" && current_company_teammate
        key = "start_page_#{current_company_teammate.organization_id}"
        current_user_preferences.update_preference(key, "start_here")
      end

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

    locked_changed = false

    if params[:open].present?
      current_user_preferences.update_preference(:vertical_nav_open, params[:open] == 'true')
    end

    if params[:locked].present?
      previous_locked = current_user_preferences.vertical_nav_locked?
      locked = params[:locked] == 'true' || params[:locked] == true
      current_user_preferences.update_preference(:vertical_nav_locked, locked)
      locked_changed = (previous_locked != locked)

      # When locking, ensure nav is open
      if locked
        current_user_preferences.update_preference(:vertical_nav_open, true)
      end
    end

    # Keep mode as an explicit user choice unless lock state changes.
    # Opening/closing the nav should be temporary UI state, not a mode change.
    if locked_changed
      sync_vertical_nav_mode_from_open_and_locked!
    end
    
    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path, notice: 'Navigation preference updated') }
      format.json {
        render json: {
          open: current_user_preferences.vertical_nav_open?,
          locked: current_user_preferences.vertical_nav_locked?,
          mode: current_user_preferences.vertical_nav_mode
        }
      }
    end
  end

  def update_vertical_nav_mode
    authorize current_user_preferences, :update_vertical_nav?

    mode = params.require(:mode).to_s
    unless VERTICAL_NAV_MODES.include?(mode)
      redirect_back(fallback_location: root_path, alert: 'Invalid vertical navigation behavior')
      return
    end

    current_user_preferences.update_preference(:vertical_nav_mode, mode)

    case mode
    when 'locked_open'
      current_user_preferences.update_preference(:vertical_nav_locked, true)
      current_user_preferences.update_preference(:vertical_nav_open, true)
    when 'closed_unless_opened'
      current_user_preferences.update_preference(:vertical_nav_locked, false)
      current_user_preferences.update_preference(:vertical_nav_open, false)
    end

    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path, notice: 'Navigation preference updated') }
      format.json {
        render json: {
          open: current_user_preferences.vertical_nav_open?,
          locked: current_user_preferences.vertical_nav_locked?,
          mode: current_user_preferences.vertical_nav_mode
        }
      }
    end
  end
  
  private

  def sync_vertical_nav_mode_from_open_and_locked!
    mode = current_user_preferences.vertical_nav_locked? ? 'locked_open' : 'closed_unless_opened'
    current_user_preferences.update_preference(:vertical_nav_mode, mode)
  end
  
  def authenticate_user!
    redirect_to login_path unless current_person
  end
end

