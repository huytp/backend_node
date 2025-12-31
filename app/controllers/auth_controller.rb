class AuthController < ApplicationController
  skip_before_action :authenticate_user, only: [:register, :login]

  # POST /auth/register
  def register
    user = User.new(user_params)

    if user.save
      render json: {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
        },
        token: user.token,
        expires_at: user.token_expires_at,
      }, status: :created
    else
      render json: { error: user.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  # POST /auth/login
  def login
    user = User.find_by(email: params[:email]&.downcase)

    if user && user.authenticate(params[:password])
      user.refresh_token unless user.token_valid?

      render json: {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
        },
        token: user.token,
        expires_at: user.token_expires_at,
      }, status: :ok
    else
      render json: { error: 'Invalid email or password' }, status: :unauthorized
    end
  end

  # GET /auth/me
  def me
    user = current_user
    if user
      render json: {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
        },
      }, status: :ok
    else
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  # POST /auth/logout
  def logout
    user = current_user
    if user
      user.update(token: nil, token_expires_at: nil)
      render json: { message: 'Logged out successfully' }, status: :ok
    else
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  private

  def current_user
    token = request.headers['Authorization']&.split(' ')&.last
    return nil unless token

    user = User.find_by(token: token)
    return nil unless user&.token_valid?

    user
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :name)
  end
end

