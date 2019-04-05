class Comment < ApplicationRecord
  resourcify

  # enum status: [:privated, :published]
  enum status: {
    privated: 'privated',
    published: 'published'
  }

  belongs_to :user
  belongs_to :commentable, polymorphic: true

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

    if self.commentable.user_id != self.user_id
      self.user.add_role :writer, self

      Activity.create(
        sender_id: self.user_id,
        receiver_id: self.commentable.user_id,
        message: 'commented on album',
        module_type: Activity.module_types[:activity],
        action_type: Activity.action_types[:comment],
        alert_type: Activity.alert_types[:both],
        status: Activity.statuses[:unread],
        assoc_type: 'Comment',
        assoc_id: self.id
      )
    end

    self.body.gsub /@(\w+)/ do |username|
      username = username.gsub('@', '')
      user = User::find_by_username(username)
      user.add_role :reader, self

      Activity.create(
        sender_id: self.user_id,
        receiver_id: user.id,
        message: 'commented on album',
        module_type: Activity.module_types[:activity],
        action_type: Activity.action_types[:comment],
        alert_type: Activity.alert_types[:both],
        status: Activity.statuses[:unread],
        assoc_type: 'Comment',
        assoc_id: self.id
      )
    end.html_safe
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
    Activity.remove('Comment', self.id)
    # self.destroy
  end
end
