class UserAlbum < ApplicationRecord
  self.table_name = "users_albums"

  enum user_type: {
    creator: 'creator',
    collaborator: 'collaborator',
    contributor: 'contributor',
    label: 'label'
  }

  # enum user_role: {
  #   artist: 'Artist',
  #   drums: 'Drums',
  #   guitar: 'Bass Guitar',
  # }

  enum status: {
    pending: 'pending',
    accepted: 'accepted',
    denied: 'denied'
  }

  belongs_to :user
  belongs_to :album

  validates :user, presence: true
  validates :album, presence: true

  after_initialize :set_default_values
  def set_default_values
    self.user_type ||= UserAlbum.user_types[:creator]
    self.user_role ||= 'Artist'
    self.status ||= UserAlbum.statuses[:accepted]
  end

  # def update_status(new_status)
  #   self.update_attributes(status: new_status)
  #   if self.user_type == UserAlbum.user_types[:collaborator]
  #     accepted_collaborators_count = UserAlbum.where(
  #       album_id: self.album_id,
  #       user_type: UserAlbum.user_types[:collaborator],
  #       status: UserAlbum.statuses[:accepted]
  #     ).size
  #     if accepted_collaborators_count = self.album.collaborators_count
  #       self.album.update_attribute(status: Album.statuses[:collaborated])
  #     end
  #   end
  # end
end
