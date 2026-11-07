class BanlistEntry < ApplicationRecord
  belongs_to :banlist
  belongs_to :card

  enum :status, { forbidden: "forbidden", limited: "limited", semi_limited: "semi_limited" }, validate: true
end
