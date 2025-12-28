class HealthController < ApplicationController
  def check
    render json: {
      status: 'ok',
      service: 'DeVPN Backend',
      version: '1.0.0',
      timestamp: Time.current.iso8601
    }
  end
end

