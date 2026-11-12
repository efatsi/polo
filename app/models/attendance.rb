class Attendance < ApplicationRecord
  STATUSES = %w[in maybe out].freeze

  belongs_to :game

  validates :name, presence: true, uniqueness: { scope: :game_id }
  validates :status, inclusion: { in: STATUSES }
end
