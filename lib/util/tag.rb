class Util::Tag
  def self.remove tag_name
    tag = ActsAsTaggableOn::Tag.find_by(name: tag_name)
    if tag.present?
      ActsAsTaggableOn::Tagging.destroy_all(tag_id: tag.id)
      tag.reload
      tag.delete if tag.taggings_count == 0
    end
  end
end
