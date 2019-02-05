class RelationSerializer < ActiveModel::Serializer
  attributes :id, :context, :status

  belongs_to :host, if: :include_host?
  belongs_to :client, if: :include_client?

  def include_host?
    instance_options[:include_host] || false
  end

  def include_client?
    instance_options[:include_client] || false
  end
end