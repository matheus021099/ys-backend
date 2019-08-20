Rails.application.routes.draw do
  devise_for :users
  get '/docs' => redirect('/swagger/index.html?url=/apidocs/api-docs.json')
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  match '/auth/twitter/callback', to: 'web#twitter_callback', via: [:get, :post]
  match '/auth/stripe_connect/callback', to: 'web#stripe_connect_callback', via: [:get, :post]

  get '/albums/:album_id/download_as_zip', to: 'web#download_as_zip'

  scope module: 'api', format: false, constraints: { id: %r{[^/]+} } do
    namespace :v2 do
      resources :genres do
      end

      resources :search, only: [] do
        collection do
          post :search_stream
          # post :search_discover
        end
      end
    end

    namespace :v1 do
      resources :settings, only: [:index, :create]

      resources :twitter, only: [] do
        collection do
          post :request_token
          post :access_token
        end
      end

      resource :auth, only: [] do
        collection do
          post :sign_in
          post :sign_out
          post :sign_up_as_listener
          post :sign_up_as_artist
          post :send_confirm_email
          post :confirm
          post :signin_url_for_twitter
          post :signin_with_social
          post :reset_password
          post :set_password
          post :is_username_available
          post :token_validity
        end
      end

      resources :users, only: [:index, :update, :destroy] do
        member do
          get :repost_price_proration
          post :set_repost_price
          post :change_password
          post :connect_stripe
          get :disconnect_stripe
          post :donate
          get :info
          get :invite
          get :reposted_feeds
          get :cart_items
          get :has_followed
          get :follow
          get :unfollow
          get :block
          get :unblock
          get :favorite
          get :unfavorite
          post :hidden_genres
          get :available_stream_period
          get :send_label_request
          get :remove_label
          get :accept_label_request
          get :deny_label_request
          post :share
          post :update_status
          post :update_role
        end

        collection do
          get :search
          # post :hidden_genres
        end
      end

      resources :devices, only: [:create]

      resources :admin, only: [] do
        collection do
          get :users
          get :signup_users
          post :approve_user
          post :deny_user
          post :toggle_view_direct_messages
          post :toggle_live_video
          post :toggle_live_video_free
          get :albums
          get :products
          post :send_global_message
          get :global_stats
        end
      end

      resources :attendees, only: [:index, :create] do
        member do
          get :invite
        end

        collection do
          get :find_by_token
        end
      end

      resources :promote, only: [] do
        collection do
          post :search_users
          post :calculate_on_suggested_reposters
          post :calculate_on_current_reposters
        end
      end

      resources :profile, only: [] do
        member do
          post :artists
          post :catalog
          post :songs
          post :merch
          post :downloaded
          post :reposted
          post :playlists
          post :sample_followings
          post :followings
          post :followers
        end
      end

      resources :payments, only: [:index] do
        collection do
          get :sent
          get :received
          post :deposit
          post :withdraw
        end

        member do
          post :refund
        end
      end

      resources :genres, only: [:index] do
      end

      resources :albums do
        member do
          get :release
          get :my_role
          # get :request_repost
          get :repost
          get :unrepost
          get :accept_collaboration
          get :deny_collaboration
          get :send_label_request
          get :remove_label
          get :accept_label_request
          get :deny_label_request
          get :make_public
          get :make_private
          get :make_live_video_only
          get :recommend
          get :unrecommend
          post :report
          get :hide
          get :download
          get :play
          post :rearrange
          post :add_tracks
          post :remove_tracks
        end

        collection do
          get :search
        end

        resources :activities, controller: 'albums/activities', only: [:index] do
          collection do
            get :stats
            get :reposted_by
            get :downloaded_by
            get :played_by
          end
        end
      end

      resources :playlists do
        member do
          post :remove_track
        end
      end

      resources :player, only: [] do
        collection do
          post :track_by_id
          post :track_by_offset
        end
      end

      resources :label, only: [] do
        collection do
          get :label_users
          get :label_albums
        end
      end

      resources :tracks, only: [:create, :update, :destroy] do
        member do
          get :download
          get :play
        end
      end

      resources :activities, only: [:index] do
        collection do
          get :metrics
          get :unread
          get :read
        end
      end

      resources :posts do
        member do
          get :view
        end
      end

      resources :tickets

      resources :comments, except: [:show] do
        member do
          get :make_public
          get :make_private
        end
      end

      resources :messages do
        collection do
          post :has_pending_repost
          get :conversations
          post :delete_conversation
        end

        member do
          get :accept_repost
          get :deny_repost
          get :accept_repost_on_free
          get :accept_collaboration
          get :deny_collaboration
        end
      end

      # resources :conversations do
      #   resources :messages do
      #   end
      # end

      resources :search, only: [] do
        collection do
          post :search_stream
          post :search_stream_v2
          post :search_discover
          post :search_global
          post :search_landing
        end
      end

      resources :presets, only: [:index, :create, :destroy] do
        member do
          get :load
        end
      end

      resources :streams, only: [:show, :create, :update, :destroy] do
        member do
          get :start
          get :stop
          get :repost
          get :can_view
          post :pay_view
          get :view
        end
      end

      namespace :shopping do
        resources :categories, only: [:index] do
        end

        resources :products do
          collection do
            post :search
          end

          member do
            get :release
            get :repost
            get :unrepost
            get :accept_collaboration
            get :deny_collaboration
            get :ordered_items
            get :tickets
          end
        end

        resources :items do
          collection do
            get :calculate_cost
            post :buy
            get :mark_all_as_shipped
          end

          member do
            post :mark_as_shipped
            get :mark_as_unshipped
            get :tickets
          end
        end

        resources :orders, only: [:index, :show] do
          collection do
            get :sent
            get :received
            get :received_export
          end

          member do
            get :hide_customer_address
          end
        end

        resources :addresses
      end
    end
  end

  require 'sidekiq/web'

  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    # Protect against timing attacks:
    # - See https://codahale.com/a-lesson-in-timing-attacks/
    # - See https://thisdata.com/blog/timing-attacks-against-string-comparison/
    # - Use & (do not use &&) so that it doesn't short circuit.
    # - Use digests to stop length information leaking (see also ActiveSupport::SecurityUtils.variable_size_secure_compare)
    ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_USERNAME"])) &
      ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_PASSWORD"]))
  end# if Rails.env.production?

  mount Sidekiq::Web, at: "/sidekiq"

  mount ActionCable.server => "/cable"
end
