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
          ActsAsTaggableOn::Tagging.where(context: 'genres', tag_id: tag.id).destroy_all
          # tag.reload
          # tag.delete if tag.taggings_count == 0
        end
        child.delete
      end
    end

    tag = ActsAsTaggableOn::Tag.find_by(name: self.id)
    if tag.present?
      ActsAsTaggableOn::Tagging.where(context: 'genres', tag_id: tag.id).destroy_all
      # tag.reload
      # tag.delete if tag.taggings_count == 0
    end
    self.delete
  end
end
