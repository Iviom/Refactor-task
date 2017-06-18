class SubscriptionService

  def initialize(user)
    @user = user
  end

  def subscribe(category_id)
    if @user.subscriptions.where(category_id: category_id.to_i).empty?
      create_subscription(category_id)
    end
  end

  protected

  def create_subscription(category_id)
    category = AdvtCategory.find_by_id(category_id)
    if category
      subscription = Subscription.new(user_id: @user.id, category_id: category.id)
      subscription.save
      @user.update_attribute(:subscribed_to_sevastopol_news, true)
    end
  end

end
