class SubscriptionsController < ApplicationController
  # GET /subscriptions/status
  def status
    render json: {
      subscription: {
        plan: @current_user.subscription_plan,
        status: @current_user.subscription_status,
        started_at: @current_user.subscription_started_at,
        expires_at: @current_user.subscription_expires_at,
        active: @current_user.subscription_active?,
      },
    }, status: :ok
  end

  # POST /subscriptions/purchase
  def purchase
    plan = params[:plan]
    payment_method = params[:payment_method] # 'google_pay' or other

    unless ['monthly', 'quarterly', 'yearly'].include?(plan)
      render json: { error: 'Invalid subscription plan' }, status: :bad_request
      return
    end

    # Calculate expiration date based on plan
    expires_at = case plan
                  when 'monthly'
                    1.month.from_now
                  when 'quarterly'
                    3.months.from_now
                  when 'yearly'
                    1.year.from_now
                  end

    # Update user subscription
    @current_user.update!(
      subscription_plan: plan,
      subscription_status: 'active',
      subscription_started_at: Time.current,
      subscription_expires_at: expires_at
    )

    render json: {
      subscription: {
        plan: @current_user.subscription_plan,
        status: @current_user.subscription_status,
        started_at: @current_user.subscription_started_at,
        expires_at: @current_user.subscription_expires_at,
        active: @current_user.subscription_active?,
      },
      message: 'Subscription activated successfully',
    }, status: :ok
  end

  # GET /subscriptions/plans
  def plans
    render json: {
      plans: [
        {
          id: 'monthly',
          name: 'Monthly Plan',
          price: 29,
          currency: 'USD',
          duration: '1 month',
          description: 'Full access for 1 month',
        },
        {
          id: 'quarterly',
          name: 'Quarterly Plan',
          price: 79,
          currency: 'USD',
          duration: '3 months',
          description: 'Full access for 3 months',
          savings: 'Save $8',
        },
        {
          id: 'yearly',
          name: 'Yearly Plan',
          price: 299,
          currency: 'USD',
          duration: '1 year',
          description: 'Full access for 1 year',
          savings: 'Save $49',
        },
      ],
    }, status: :ok
  end
end

