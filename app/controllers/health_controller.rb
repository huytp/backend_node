class HealthController < ApplicationController
  def check
    render json: {
      status: 'ok',
      service: 'DeVPN Backend',
      version: '1.0.0',
      timestamp: Time.current.iso8601
    }
  end

  # POST /health/upload_test - Endpoint để test upload speed
  # Nhận POST request với data lớn và trả về thông tin để đo upload speed
  def upload_test
    # Chỉ chấp nhận request body để đo upload speed
    # Không cần xử lý data, chỉ cần nhận và trả về timestamp
    render json: {
      status: 'ok',
      received: request.content_length || 0,
      timestamp: Time.current.iso8601
    }
  end
end

