module Api::V1
  class PostsController < ApiController
    before_action :set_post, only: [:update, :show, :destroy, :view]

    swagger_controller :posts, 'Posts'

    swagger_api :index do |api|
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def index
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 10).to_i

      posts = policy_scope(Post)
        .where.not(user_id: current_user.block_list)
        .order('created_at desc').page(page).per(per_page)

      render_success(
        posts: ActiveModel::SerializableResource.new(posts),
        pagination: pagination(posts)
      )
    end


    swagger_api :create do |api|
      summary 'add a post'
      param :form, 'post[media_type]', :string, :required, 'image, video'
      param :form, 'post[media]', :File, :optional
      param :form, 'post[media_name]', :string, :optional
      param :form, 'post[cover]', :File, :optional
      param :form, 'post[description]', :string, :required
      param :form, 'post[assoc_type]', :string, :optional, 'Album, ShopProduct'
      param :form, 'post[assoc_id]', :string, :optional
      param :form, 'post[assoc_selector]', :string, :optional, 'products, albums, playlists, reposted, downloaded'
    end
    def create
      @post = Post.new(user: current_user)
      authorize @post

      @post.attributes = permitted_attributes(@post)

      if @post.save
        render_success @post
      else
        render_errors @post, :unprocessable_entity
      end
    end


    swagger_api :update do |api|
      summary 'update a post'
      param :path, :id, :string, :required
      param :form, 'post[media_type]', :string, :required, 'image, video'
      param :form, 'post[media]', :File, :optional
      param :form, 'post[media_name]', :string, :optional
      param :form, 'post[cover]', :File, :optional
      param :form, 'post[description]', :string, :required
      param :form, 'post[assoc_type]', :string, :optional, 'Album, ShopProduct'
      param :form, 'post[assoc_id]', :string, :optional
      param :form, 'post[assoc_selector]', :string, :optional, 'products, albums, playlists, reposted, downloaded'
    end
    def update
      authorize @post

      if params[:post][:media].present?
        unless params[:post][:media].instance_of? ActionDispatch::Http::UploadedFile
          @post.remove_media!
        end
      end
      @post.attributes = permitted_attributes(@post)

      if @post.save
        render_success @post
      else
        render_errors @post, :unprocessable_entity
      end
    end


    swagger_api :destroy do |api|
      param :path, :id, :string, :required
    end
    def destroy
      authorize @post

      @post.destroy

      render_success true
    end


    setup_authorization_header(:view)
    swagger_api :view do |api|
      summary 'view a post'
      param :path, :id, :string, :required
    end
    def view
      authorize @post
      @post.play(current_user)
      render_success true
    end

    private

    def set_post
      @post = Post.find(params[:id])
    end
  end
end
