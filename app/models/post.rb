class Post < ApplicationRecord
  enum media_types: {
    image: 'image',
    video: 'video'
  }

  enum assoc_selectors: {
    products: 'products',
    albums: 'albums',
    playlists: 'playlists',
    reposted: 'reposted',
    downloaded: 'downloaded'
  }

  belongs_to :user
  belongs_to :assoc, polymorphic: true, optional: true
  has_many :comments, as: :commentable, dependent: :destroy

  mount_uploader :media, FileUploader

  def media_url
    if media_name.blank?
      self.media.url
    else
      self.media.url(query: {:"response-content-disposition" => "attachment; filename=\"#{media_name}\""})
    end
  end
end
