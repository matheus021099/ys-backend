class AlbumPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(user: user)
      end
    end
  end

  def show?
    true
  end

  def create?
    true
    # user.admin? || user.artist?
  end

  def update?
    possess?
  end

  def destroy?
    possess?
  end

  def request_respost
    moderate?
  end

  def release?
    possess?
  end

  def request_repost?
    moderate?
  end

  def repost?
    user.id != record.user_id
  end

  def unrepost?
    moderate?
  end

  def accept_collaboration?
    true
  end

  def deny_collaboration?
    true
  end

  def send_label_request?
    user.label? && record.user.artist? && Relation.exists?(host_id: user.id, client_id: record.user_id, context: 'label', status: Relation.statuses[:accepted])
  end

  def remove_label?
    user.label? && Relation.exists?(host_id: user.id, client_id: record.user_id, context: 'label', status: Relation.statuses[:accepted])
  end

  def accept_label_request?
    user.id == record.user_id
  end

  def deny_label_request?
    user.id == record.user_id
  end

  def make_public?
    record.user == user
  end

  def make_private?
    record.user == user
  end

  def recommend?
    user.admin? || user.moderator?
  end

  def unrecommend?
    user.admin? || user.moderator?
  end

  def hide?
    moderate?
  end

  def download?
    true
  end

  def play?
    true
  end

  def rearrange?
    possess?
  end

  def add_tracks?
    possess?
  end

  def remove_tracks?
    possess?
  end

  def remove_track?
    possess?
  end

  def permitted_attributes
    [
      :album_type,
      :name,
      :description,
      :cover,
      :is_only_for_live_stream,
      :is_content_acapella,
      :is_content_instrumental,
      :is_content_stems,
      :is_content_remix,
      :is_content_dj_mix,
      :enabled_sample,
      :released_at,
      :location,
    ]
  end

  private
  def possess?
    user.admin? || record.user == user
  end

  def moderate?
    Feed.where(consumer_id: user.id, assoc_type: 'Album', assoc_id: record.id).size > 0
  end
end