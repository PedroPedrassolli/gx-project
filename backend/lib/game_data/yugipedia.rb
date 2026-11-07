require "net/http"

module GameData
  # Cliente mínimo da API da Yugipedia (MediaWiki). Pede de 50 em 50 páginas, espera um
  # pouco entre um pedido e outro e se identifica no User-Agent, como a API pede.
  class Yugipedia
    class Error < StandardError; end

    API = URI("https://yugipedia.com/api.php")
    USER_AGENT = "gx-project-dados/1.0 (https://github.com/PedroPedrassolli/gx-project)".freeze
    BATCH = 50

    # Uma página na revisão lida. A fonte de cada dado é o link dessa revisão.
    Page = Data.define(:id, :revision, :title, :text) do
      def source = "https://yugipedia.com/index.php?oldid=#{revision}"
    end

    def initialize(pause: 1)
      @pause = pause
    end

    # { id => Page }. Id que não existe fica de fora.
    def pages_by_id(ids)
      ids.each_slice(BATCH).each_with_object({}) do |slice, found|
        query(pageids: slice.join("|"))["pages"].each do |data|
          page = build(data)
          found[page.id] = page if page
        end
      end
    end

    # { título pedido => Page }, seguindo redirecionamentos (nome antigo da carta → página
    # atual). Com section: 0, vem só o começo da página, onde fica a infobox.
    def pages_by_title(titles, section: nil)
      titles.uniq.each_slice(BATCH).each_with_object({}) do |slice, found|
        wiki_titles = slice.map { |title| wiki_title(title) }
        result = query({ titles: wiki_titles.join("|"), redirects: 1, rvsection: section }.compact)
        pages = result["pages"].filter_map { |data| build(data) }.index_by(&:title)
        slice.zip(wiki_titles).each do |title, wiki|
          page = pages[final_title(result, wiki)]
          found[title] = page if page
        end
      end
    end

    # Títulos das páginas de uma categoria, pelo id da categoria.
    def category_members(category_id)
      request(action: "query", list: "categorymembers", cmpageid: category_id, cmlimit: 500)
        .dig("query", "categorymembers").map { |member| member["title"] }
    end

    private

    def query(params)
      request(action: "query", prop: "revisions", rvprop: "ids|content", rvslots: "main", **params)
        .fetch("query")
    end

    def request(params)
      sleep(@pause)
      uri = API.dup
      uri.query = URI.encode_www_form(params.merge(format: "json", formatversion: 2))
      response = Net::HTTP.get_response(uri, "User-Agent" => USER_AGENT)
      raise Error, "a Yugipedia respondeu #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def build(data)
      revision = data["revisions"]&.first
      return unless revision

      Page.new(id: data["pageid"], revision: revision["revid"], title: data["title"],
               text: revision.dig("slots", "main", "content"))
    end

    # No MediaWiki, # num título é âncora de seção: a página de "Luster Dragon #2" se chama
    # "Luster Dragon 2".
    def wiki_title(title) = title.delete("#")

    # O título pedido pode ser normalizado (maiúscula, espaço) e redirecionado.
    def final_title(result, title)
      [ "normalized", "redirects" ].reduce(title) do |current, key|
        result.fetch(key, []).find { |change| change["from"] == current }&.fetch("to") || current
      end
    end
  end
end
