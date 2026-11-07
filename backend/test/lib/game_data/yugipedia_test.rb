require "test_helper"
require "net/http"

describe GameData::Yugipedia do
  let(:client) { GameData::Yugipedia.new(pause: 0) }

  def answer(body)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.stubs(:body).returns(body.to_json)
    response
  end

  def page(id, title, text) = { "pageid" => id, "title" => title, "revisions" => [ { "revid" => id * 10, "slots" => { "main" => { "content" => text } } } ] }

  it "busca páginas pelo id e deixa de fora as que não existem" do
    body = { "query" => { "pages" => [ page(1, "Um", "texto"), { "pageid" => 2, "missing" => true } ] } }
    Net::HTTP.expects(:get_response).with do |uri, headers|
      uri.query.include?("pageids=1%7C2") && headers["User-Agent"].start_with?("gx-project-dados")
    end.returns(answer(body))

    pages = client.pages_by_id([ 1, 2 ])

    _(pages.keys).must_equal [ 1 ]
    _(pages[1].text).must_equal "texto"
    _(pages[1].source).must_equal "https://yugipedia.com/index.php?oldid=10"
  end

  it "busca pelo título seguindo a normalização e o redirecionamento" do
    body = { "query" => {
      "normalized" => [ { "from" => "alkana Knight Joker", "to" => "Alkana Knight Joker" } ],
      "redirects" => [ { "from" => "Alkana Knight Joker", "to" => "Arcana Knight Joker" } ],
      "pages" => [ page(3, "Arcana Knight Joker", "| password = 06150044") ]
    } }
    Net::HTTP.expects(:get_response).with { |uri, _headers| uri.query.include?("rvsection=0") }.returns(answer(body))

    pages = client.pages_by_title([ "alkana Knight Joker", "Sem Página" ], section: 0)

    _(pages.keys).must_equal [ "alkana Knight Joker" ]
    _(pages["alkana Knight Joker"].title).must_equal "Arcana Knight Joker"
  end

  it "lista os títulos de uma categoria" do
    body = { "query" => { "categorymembers" => [ { "title" => "Pacote A" }, { "title" => "Pacote B" } ] } }
    Net::HTTP.expects(:get_response).with { |uri, _headers| uri.query.include?("cmpageid=7") }.returns(answer(body))

    _(client.category_members(7)).must_equal [ "Pacote A", "Pacote B" ]
  end

  it "avisa quando a Yugipedia não responde 200" do
    Net::HTTP.stubs(:get_response).returns(Net::HTTPServiceUnavailable.new("1.1", "503", "Unavailable"))

    error = _ { client.category_members(7) }.must_raise GameData::Yugipedia::Error
    _(error.message).must_include "503"
  end
end
