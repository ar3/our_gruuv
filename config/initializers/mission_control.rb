# Mission Control Jobs dashboard: use our ApplicationController so we get session auth,
# current_person, impersonating?, etc. Then restrict access to og_admin or when impersonating.
MissionControl::Jobs.base_controller_class = "ApplicationController"
MissionControl::Jobs.http_basic_auth_enabled = false

Rails.application.config.to_prepare do
  MissionControl::Jobs::ApplicationController.class_eval do
    before_action :authenticate_person!
    before_action :authorize_mission_control_access!

    def authorize_mission_control_access!
      return if current_person&.og_admin?
      return if impersonating?

      redirect_to root_path, alert: "Not authorized to view the jobs dashboard."
    end
  end
end
