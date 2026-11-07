class Banlist < ApplicationRecord
  has_many :entries, class_name: "BanlistEntry", dependent: :destroy
end
