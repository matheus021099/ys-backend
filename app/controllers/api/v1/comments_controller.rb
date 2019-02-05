module Api::V1
  class CommentsController < ApiController
    swagger_controller :comments, 'Comments'
    before_action :set_comment, only: [:update, :destroy, :make_public, :make_private]


    swagger_api :index do |api|
      summary 'list all comments'
      param_list :query, :commentable_type, :string, :required, 'Commantable Type', [ 'Album', 'ShopProduct' ]
      param :query, :commentable_id, :string, :required
    end
    def index
      skip_policy_scope

      commentable = Album.find(params[:commentable_id])
      comments_1 = commentable.comments.where(status: Comment.statuses[:published]).pluck(:id)
      comments_2 = commentable.comments.with_roles([:writer, :reader], current_user).pluck(:id)
      comment_ids = comments_1 + comments_2
      comments = Comment.where('id IN (?)', comment_ids).where.not(user_id: current_user.block_list).order('created_at desc')

      render_success ActiveModel::Serializer::CollectionSerializer.new(
        comments,
        serializer: CommentSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_commenter: true
      )
    end


    swagger_api :create do |api|
      summary 'add a comment'
      param :form, 'comment[commentable_type]', :string, :required
      param :form, 'comment[commentable_id]', :string, :required
      param :form, 'comment[body]', :string, :required
    end
    def create
      @comment = Comment.new(user: current_user)
      authorize @comment
      @comment.attributes = permitted_attributes(@comment)
      @comment.save
      result = CommentSerializer.new(
        @comment,
        include_commenter: true,
        include_readers: true
      ).as_json
      if @comment.commentable.instance_of? Album
        ActionCable.server.broadcast("comments_#{@comment.commentable_id}", {
          action: 'create',
          comment: result
        })
      end
      # render_success @comment
      # render json: @comment, serializer: CommentSerializer, scope: OpenStruct.new(current_user: current_user), include_commenter: true
      render json: result
    end


    swagger_api :update do |api|
      summary 'update a comment'
      param_list :form, :status, :string, :required, 'Status', Comment.statuses
    end
    def udpate
      authorize @comment
      @comment.status = Comment.statuses[params[:status]]
      @comment.save
      result = CommentSerializer.new(
        @comment,
        include_commenter: true,
        include_readers: true
      ).as_json
      if @comment.commentable.instance_of? Album
        ActionCable.server.broadcast("comments_#{@comment.commentable_id}", {
          action: 'update',
          comment: result
        })
      end
      # render_success @comment
      # render json: @comment, serializer: CommentSerializer, scope: OpenStruct.new(current_user: current_user), include_commenter: true
      render json: result
    end


    swagger_api :destroy do |api|
      summary 'remove a comment'
      param :path, :id, :string, :required
    end
    def destroy
      authorize @comment
      comment_id = @comment.id
      @comment.remove
      if @comment.commentable.instance_of? Album
        ActionCable.server.broadcast("comments_#{@comment.commentable_id}", {
          action: 'delete',
          comment_id: comment_id
        })
      end
      render_success true
    end


    setup_authorization_header(:make_public)
    swagger_api :make_public do |api|
      summary 'make a comment public'
      param :path, :id, :string, :required
    end
    def make_public
      authorize @comment
      @comment.make_public

      if @comment.commentable.instance_of? Album
        result = CommentSerializer.new(
          @comment,
          include_commenter: true,
          include_readers: true
        ).as_json
        ActionCable.server.broadcast("comments_#{@comment.commentable_id}", {
          action: 'update',
          comment: result
        })
      end

      render_success true
    end


    setup_authorization_header(:make_private)
    swagger_api :make_private do |api|
      summary 'make a comment private'
      param :path, :id, :string, :required
    end
    def make_private
      authorize @comment
      @comment.make_private

      if @comment.commentable.instance_of? Album
        result = CommentSerializer.new(
          @comment,
          include_commenter: true,
          include_readers: true
        ).as_json
        ActionCable.server.broadcast("comments_#{@comment.commentable_id}", {
          action: 'update',
          comment: result
        })
      end

      render_success true
    end


    private
    def set_comment
      @comment = Comment.find(params[:id])
    end
  end
end