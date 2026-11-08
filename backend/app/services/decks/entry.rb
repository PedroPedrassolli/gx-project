module Decks
  # Uma linha do deck: a carta, a seção ("main", "extra" ou "side"), quantas cópias e se ela
  # é Destiny. As linhas do deck no banco respondem aos mesmos métodos (Decks::Validator).
  Entry = Struct.new(:card_id, :section, :quantity, :destiny)
end
