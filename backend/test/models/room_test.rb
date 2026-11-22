require "test_helper"

class RoomTest < ActiveSupport::TestCase
  let(:owner) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "18+") }

  it "gera códigos de 6 caracteres sem 0, O, 1 e I" do
    codes = Array.new(200) { Room.new_code }

    assert(codes.all? { |code| code.match?(/\A[A-HJ-NP-Z2-9]{6}\z/) })
  end

  it "não guarda best_of: não há melhor de 3 (GXP-129)" do
    _(Room.connection.column_exists?(:rooms, :best_of)).must_equal false
  end

  it "o primeiro lugar livre é o de número mais baixo" do
    room = Room.create!(owner:, code: "ABC234")
    room.players.create!(user: owner, seat: 1)

    assert_equal [ 2, 0 ], [ room.seats, room.free_seat ]
  end

  it "apagar a conta apaga a sala que o jogador criou e a vaga dele" do
    room = Room.create!(owner:, code: "ABC234")
    room.players.create!(user: owner, seat: 0)
    owner.destroy!

    assert_equal [ 0, 0 ], [ Room.count, RoomPlayer.count ]
  end
end
