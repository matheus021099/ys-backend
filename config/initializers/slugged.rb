module FriendlyId::Slugged
  def resolve_friendly_id_conflict(candidates)
    if candidates.first.present?
      column = friendly_id_config.slug_column
      separator = friendly_id_config.sequence_separator
      slug = normalize_friendly_id(candidates.first)
      # to prevent issuse in case of [abc, abc xyz, abc]
      # slug_start = "#{slug}#{separator}"
      slug_start = "#{slug}#{separator}#{separator}"
      sequence = self.class.where("#{column} like '#{slug_start}%'").maximum("SUBSTR(#{column}, #{slug_start.length + 1})::Int")
      if sequence.present?
        sequence += 1
      else
        sequence = 2
      end
      "#{slug}#{separator}#{separator}#{sequence}"
    else
      [candidates.first, SecureRandom.uuid].compact.join(friendly_id_config.sequence_separator)
    end
  end
end