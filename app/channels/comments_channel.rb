class CommentsChannel < ApplicationCable::Channel
  def subscribed
    # album_comments
    stream_from "comments_#{params[:album_id]}"
  end

  def unsubscribed
  end
end
