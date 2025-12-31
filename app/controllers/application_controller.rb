class ApplicationController < ActionController::API
  # API only controller
  before_action :authenticate_user

  protected

  def authenticate_user
    token = request.headers['Authorization']&.split(' ')&.last
    @current_user = User.find_by(token: token) if token

    unless @current_user&.token_valid?
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end
end

