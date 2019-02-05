class Relation < ApplicationRecord
  enum status: {
    pending: 'pending',
    accepted: 'accepted',
    denied: 'denied'
  }

  belongs_to :host, class_name: 'User'
  belongs_to :client, class_name: 'User'

  after_initialize :set_default_values
  def set_default_values
    self.context ||= 'label'
    self.status ||= Relation.statuses[:pending]
  end

  def self.insert(host: nil, client: nil, context: 'label', status: Relation.statuses[:pending])
    relation = Relation.where(
      host_id: host.id,
      client_id: client.id,
      context: context
    ).where.not(status: Relation.statuses[:denied])
    return false if relation.present?

    Relation.create(
      host_id: host.id,
      client_id: client.id,
      context: context,
      status: status
    )
  end
end