class Comment < ApplicationRecord
  resourcify

  # enum status: [:privated, :published]
  enum status: {
    privated: 'privated',
    published: 'published'
  }

  belongs_to :user
  belongs_to :commentable, polymorphic: true
  has_many :activities, as: :assoc, dependent: :destroy

  # default
  after_initialize :set_default_values
  def set_default_values
    self.status ||= Comment.statuses[:privated]
  end

  # before_create :do_before_create
  after_create :do_after_create
  before_destroy :remove

  # def do_before_create
  #   self.status = Comment.statuses[:published] if self.commentable.user_id == self.user_id
  # end

  def do_after_create
    self.commentable.commented += 1 and self.commentable.save if self.commentable_type == 'Album'

    self.commentable.user.add_role :writer, self

    # send PN when owner mention himself
    users = []
    if self.commentable.user_id != self.user_id
      self.user.add_role :writer, self
      users << self.commentable.user
    end

    self.body.gsub /@(\w+)/ do |username|
      username = username.gsub('@', '').downcase
      u = User.includes(:devices).find_by_username(username)
      if u.present?
        u.add_role :reader, self
        users << u
      end
    end.html_safe
    users.uniq! { |u| u.id }

    message_body = "commented on #{commentable_type}"
    users.each do |u|
      if u.id == self.commentable.user_id
        Activity.create(
          sender_id: self.user_id,
          receiver_id: u.id,
          message: "commented on your #{commentable_type}",
          module_type: Activity.module_types[:activity],
          action_type: Activity.action_types[:comment],
          alert_type: Activity.alert_types[:both],
          status: Activity.statuses[:unread],
          assoc_type: self.commentable_type,
          assoc_id: self.commentable_id
        ) unless self.commentable_type == 'Stream'
      else
        Activity.create(
          sender_id: self.user_id,
          receiver_id: u.id,
          message: "mentioned you in #{commentable_type}",
          module_type: Activity.module_types[:activity],
          action_type: Activity.action_types[:comment],
          alert_type: Activity.alert_types[:both],
          status: Activity.statuses[:unread],
          assoc_type: self.class.name,
          assoc_id: self.id
        )
      end

      PushNotificationWorker.perform_async(
        u.devices.pluck(:token),
        FCMService::push_notification_types[:commented],
        message_body,
        CommentSerializer.new(
          self,
          scope: OpenStruct.new(current_user: self.user),
          include_commenter: true,
        ).as_json
      ) if u.id != self.commentable.user_id || self.commentable_type != 'Stream'
    end

    true
  end

  def readable_user_ids
    query_string = <<-SQL
      SELECT ur.user_id
      FROM users_roles ur
      INNER JOIN roles r ON r.id = ur.role_id
      WHERE r.resource_type = '#{self.class.name}' AND r.resource_id = '#{self.id}'
    SQL
    ActiveRecord::Base.connection.execute(query_string).to_a.pluck('user_id')
  end

  def make_public
    self.update_attributes(status: Comment.statuses[:published])
  end

  def make_private
    self.update_attributes(status: Comment.statuses[:privated])
  end

  def remove
    self.commentable.commented -= 1 and self.commentable.save if self.commentable_type == 'Album'

    users = User.with_role(:writer, self)
    users.each{ |user| user.remove_role :writer, self }

    users = User.with_role(:reader, self)
    users.each{ |user| user.remove_role :reader, self }

    self.roles.destroy

    # #TODO - could raise an issue, coz activity refer comment in assoc
    # Activity.remove(self.class.to_s.underscore, self.id)
    Activity.remove(self.class.name, self.id)
    # self.destroy
  end
end
