class SyncGroupsioJob < ApplicationJob
  queue_as :default
  # Don't stack up syncs if one runs long.
  limits_concurrency to: 1, key: "groupsio_sync", duration: 10.minutes

  def perform(max_topics: 20)
    Groupsio::Sync.call(max_topics:)
  end
end
