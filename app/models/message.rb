class Message < ApplicationRecord
  belongs_to :game

  validates :msg_num, presence: true, uniqueness: true
  validates :sent_at, presence: true
end
