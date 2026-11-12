class Game < ApplicationRecord
  STATUSES = %w[proposed confirmed cancelled not_a_game].freeze
  # Fields an admin can override. Once overridden they're "locked" and Claude won't change them.
  LOCKABLE_FIELDS = %w[starts_at location status summary attendances].freeze
  DEFAULT_LOCATION = "Crozet Park".freeze
  BACKUP_LOCATION = "Beaver Creek Reservoir".freeze
  # A game still counts as "upcoming" for a few hours after its start time.
  UPCOMING_GRACE = 3.hours

  has_many :messages, -> { order(:sent_at, :msg_num) }, dependent: :destroy
  has_many :attendances, -> { order(:name) }, dependent: :destroy

  validates :groupsio_topic_id, presence: true, uniqueness: true
  validates :subject, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :listed, -> { where.not(status: "not_a_game") }
  scope :upcoming, -> { listed.where(starts_at: UPCOMING_GRACE.ago..).order(:starts_at) }
  scope :past, -> { listed.where(starts_at: ...UPCOMING_GRACE.ago).order(starts_at: :desc) }
  # Threads Claude couldn't pin to a date yet (e.g. "Sunday polo?" with no replies).
  scope :undated, -> { listed.where(starts_at: nil).order(last_post_at: :desc) }

  # The game to feature on the home page: the soonest non-cancelled upcoming game,
  # else a cancelled one (so people see it's off), else a fresh thread with no date yet.
  def self.next_up
    upcoming.where.not(status: "cancelled").first ||
      upcoming.first ||
      undated.where(last_post_at: 7.days.ago..).first
  end

  def locked?(field) = locked_fields.include?(field.to_s)

  def needs_extraction?
    latest = messages.maximum(:msg_num)
    latest.present? && (extracted_through_msg_num.nil? || latest > extracted_through_msg_num)
  end

  def playing = attendances.select { _1.status == "in" }
  def maybe = attendances.select { _1.status == "maybe" }
  def out = attendances.select { _1.status == "out" }

  def groupsio_url = "https://groups.io/g/#{Groupsio.group_name}/topic/#{groupsio_topic_id}"
end
