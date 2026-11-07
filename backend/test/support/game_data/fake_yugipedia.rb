module GameData
  # Yugipedia de mentira para os testes: guarda as páginas na memória e responde como o
  # cliente de verdade, com um redirecionamento de nome antigo para o atual.
  class FakeYugipedia
    REDIRECTS = { "Old Name" => "New Name" }.freeze

    def initialize(category:, fixed:, cards:)
      @category, @fixed, @cards = category, fixed, cards
    end

    def category_members(_id) = @category.map(&:title)
    def pages_by_id(ids) = @fixed.slice(*ids)

    def pages_by_title(titles, section: nil)
      everything = (@category + @cards).index_by(&:title)
      titles.each_with_object({}) do |title, found|
        page = everything[REDIRECTS.fetch(title, title)]
        found[title] = page if page
      end
    end
  end
end
