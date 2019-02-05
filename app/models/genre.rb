class Genre < ApplicationRecord
  has_ancestry

  validates :name, presence: true

  extend FriendlyId
  friendly_id :name, use: :slugged

  def remove
    if self.ancestry.blank?
      self.children.each do |child|
        tag = ActsAsTaggableOn::Tag.find_by(name: child.id)
        if tag.present?
          ActsAsTaggableOn::Tagging.destroy_all(tag_id: tag.id)
          tag.reload
          tag.delete if tag.taggings_count == 0
        end
        child.delete
      end
    end

    #TODO it might remove block users if user_id is same as genre_id
    tag = ActsAsTaggableOn::Tag.find_by(name: self.id)
    if tag.present?
      ActsAsTaggableOn::Tagging.destroy_all(tag_id: tag.id)
      tag.reload
      tag.delete if tag.taggings_count == 0
    end
    self.delete
  end

end