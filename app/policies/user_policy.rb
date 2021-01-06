class UserPolicy < ApplicationPolicy
  def update?
    user.admin? || user.id == record.id
  end

  def destroy?
    user.admin? || user.moderator? || user.id == record.id
  end

  def reset_password?
    record.active_for_authentication? || (user.present? && user.admin?)
  end

  def repost_price_proration?
    user.id == record.id
  end

  def set_repost_price?
    user.id == record.id
  end

  def change_password?
    user.id == record.id
  end

  def check_stripe_connection?
    true
  end

  def instant_payouts?
    user.id == record.id
  end

  def donate?
    user.id != record.id
  end

  def video_credit?
    user.id != record.id
  end

  def info?
    (user && user.id == record.id) || !(record.superadmin? || record.admin?)
  end

  def invite?
    !user.listener? && record.listener? && ['artist', 'brand', 'label'].include?(record.request_role)
  end

  def follow?
    !user.moderator? && user.id != record.id && !user.following?(record)
  end

  def unfollow?
    user.id != record.id && user.username != ENV['PUBLIC_RELATIONS_USERNAME']
  end

  def block?
    user.id != record.id
  end

  def unblock?
    user.id != record.id
  end

  def favorite?
    user.id != record.id
  end

  def unfavorite?
    user.id != record.id
  end

  def hidden_genres?
    user.id == record.id
  end

  def send_label_request?
    user.label? && record.artist?
  end

  def remove_label?
    (user.label? && record.artist?) || (user.artist? && record.label?)
  end

  def accept_label_request?
    user.artist? && record.label?
  end

  def deny_label_request?
    user.artist? && record.label?
  end

  def share?
    user.id != record.id
  end

  def update_status?
    user.admin? || user.moderator?
  end

  def update_role?
    user.admin? && user.moderator? && user.id != record.id
  end

  def permitted_attributes
    attributes = [
      :username,
      :display_name,
      :first_name,
      :last_name,
      :contact_url,
      :email,
      :password,
      :avatar,
      :avatar_cache,
      :remove_avatar,
      :repost_price,
      :enable_alert,
      :payment_provider,
      :payment_account_id,
      :payment_account_type,
      :payment_publishable_key,
      :payment_access_code,

      :return_policy,
      :shipping_policy,
      :size_chart,
      :privacy_policy,

      :request_role,
      :social_user_id,

      :genre_id,
      # :release_count,
      # :soundcloud_url,
      # :basecamp_url,
      # :website_url,
      :history,

      :year_of_birth,
      :gender,
      :country,
      :city,

      :artist_type,
      :released_albums_count,
      :years_since_first_released,
      :will_run_live_video,
      :will_sell_products,
      :will_sell_physical_copies,
      :annual_income_on_merch_sales,
      :annual_performances_count,
      :signed_status,
      :performance_rights_organization,
      :ipi_cae_number,
      :website_1_url,
      :website_2_url,

      :sub_genre_id,
      :is_business_registered,
      :artists_count,

      :standard_brand_type,
      :customized_brand_type,
      :employees_count,
      :years_in_business,
      :will_sell_music_related_products,
      :products_count,
      :annual_income,

      :status
    ]

    # if user.present? && user.admin?
    #   # attributes << :role
    # end

    attributes
  end
end
