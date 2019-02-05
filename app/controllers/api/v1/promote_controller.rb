module Api::V1
  class PromoteController < ApiController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    swagger_controller :promote, 'related to promote feature'


    setup_authorization_header(:search_users)
    swagger_api :search_users do |api|
      summary 'search users'
      param :form, :repost_price, :integer, :optional, '100, 500, 1000, etc'
      param :form, :followers_count, :integer, :optional, '0, 1000, 5000, etc. different: 0 and not_passed'
      param :form, :user_type, :string, :optional, 'artist, brand, label, listener'
      param :form, :username, :string, :optional
    end
    def search_users
      repost_price = params[:repost_price] ? params[:repost_price].to_i : 'any'
      followers_count = params[:followers_count] ? params[:followers_count].to_i : 'any'
      user_type = params[:user_type] || 'any'
      username = params[:username] || ''

      reposter_ids = Feed.where('consumer_id = publisher_id').where(
        assoc_type: params[:assoc_type],
        assoc_id: params[:assoc_id],
        feed_type: Feed.feed_types[:repost]
      ).pluck(:publisher_id).uniq
      reposter_ids << current_user.id

      query = User#.preload(:roles)
        .select('users.*, t1.followers_count AS followers_count, t3.name AS role_name')
        .joins("LEFT JOIN (SELECT follows.followable_id, follows.followable_type, count(*) AS followers_count FROM follows "\
            "GROUP BY follows.followable_id, follows.followable_type) AS t1 "\
            "ON users.id = t1.followable_id AND t1.followable_type='User'")
        .joins("LEFT JOIN users_roles t2 ON users.id = t2.user_id "\
          "LEFT JOIN roles t3 ON t2.role_id = t3.id ")
        .where("t3.resource_type IS NULL")
        .where.not(id: reposter_ids)
        .order('COALESCE(followers_count, 0) DESC')

        # .joins("LEFT JOIN (SELECT t2.name as role_name FROM roles 

      if repost_price != 'any' && repost_price > 0
        query = query.where(repost_price: repost_price)
      end

      if followers_count != 'any'
        if followers_count == 0
          query = query.where('followers_count > 0 AND followers_count < ?', 1000)
        else
          query = query.where('followers_count >= ?', followers_count)
        end
      else
        query = query.where('followers_count > 0')
      end

      unless username.blank?
        query = query.where('username ILIKE ?', "#{username}%")
      end

      unless user_type == 'any'
        query = query.where('t3.name = ?', user_type)
      end

      users = query.limit(30)

      render json: ActiveModel::Serializer::CollectionSerializer.new(
        users,
        serializer: UserSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_recent: true
      )
    end


    setup_authorization_header(:calculate_on_suggested_reposters)
    swagger_api :calculate_on_suggested_reposters do |api|
      summary 'calculate total_potential_reach and cost on suggested reposters'
      param :form, :user_ids, :string, :required
    end
    def calculate_on_suggested_reposters
      user_ids = params[:user_ids].split(',') if params[:user_ids].present?
      total_cost = User.where(id: user_ids).sum(:repost_price)
      total_potential_reach = Follow.where(
        followable_type: 'User',
        followable_id: user_ids,
        follower_type: 'User'
      ).pluck(:follower_id).uniq.size

      render json: {
        total_potential_reach: total_potential_reach,
        total_cost: total_cost
      }
    end


    setup_authorization_header(:calculate_on_current_reposters)
    swagger_api :calculate_on_current_reposters do |api|
      summary 'calculate total_potential_reach and cost on current reposters'
      param :form, :assoc_type, :string, :required, 'Album, ShopProduct'
      param :form, :assoc_id, :string, :required
    end
    def calculate_on_current_reposters
      assoc = params[:assoc_type].constantize.find_by(id: params[:assoc_id])
      render_error 'Not found assoc', :unprocessable_entity and return unless assoc.present?

      reposter_ids = Feed.where('consumer_id = publisher_id').where(
        assoc_type: assoc.class.name,
        assoc_id: assoc.id,
        feed_type: Feed.feed_types[:repost]
      ).pluck(:publisher_id).uniq

      total_paid = Payment.where(
        sender_id: current_user.id,
        assoc_type: assoc.class.name,
        assoc_id: assoc.id,
        payment_type: Payment.payment_types[:repost],
        status: Payment.statuses[:done]
      ).sum(:sent_amount)

      total_potential_reach = Follow.where(
        followable_type: 'User',
        followable_id: reposter_ids,
        follower_type: 'User'
      ).pluck(:follower_id).uniq.size

      total_actual_reach = Feed.where(
        publisher_id: assoc.user_id,
        assoc_type: assoc.class.name,
        assoc_id: assoc.id,
        feed_type: Feed.feed_types[:play]
      ).pluck(:consumer_id).uniq.size

      reposters = User.where(id: reposter_ids)

      render json: {
        reposters: ActiveModel::Serializer::CollectionSerializer.new(
          reposters,
          serializer: UserSerializer,
          scope: OpenStruct.new(current_user: current_user),
        ),
        total_potential_reach: total_potential_reach,
        total_actual_reach: total_actual_reach,
        total_paid: total_paid,
      }
    end

  end
end