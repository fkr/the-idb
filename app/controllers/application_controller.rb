class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :user_authentication
  before_action :set_mailer_options
  before_action :set_paper_trail_whodunnit

  attr_accessor :current_user

  helper_method :current_user

  rescue_from 'Redis::CannotConnectError', with: :show_redis_error

  private

  def user_authentication
    return true if @current_user
    if session[:user_id]
      @current_user = User.find(session[:user_id])
      return true if @current_user
    end
    redirect_to login_url
  end

  def user_for_paper_trail
    return unless session[:user_id]
    session[:user_id]
  end

  def trigger_version_change(object, username = "")
    return if object.versions.last.nil?
    VersionChangeWorker.perform_async(object.versions.last.id, username)
  end

  def set_mailer_options
    ActionMailer::Base.default_url_options = {
      :host => IDB.config.mail.host,
      :protocol => IDB.config.mail.protocol
    }
  end

  def show_redis_error(exception)
    render_error(exception, 'It looks like there is a problem with the Redis DB')
  end

  def render_error(exception, message = nil)
    message ||= 'Sorry, something bad happened'

    render 'shared/error', status: 500, locals: {
      exception: exception,
      message: message
    }
  end
end