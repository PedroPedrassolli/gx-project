require "test_helper"

# Confere os YAML de db/seeds/jogo: os gerados pelo `dados:jogo` e o de disponibilidade,
# escrito à mão. Um não pode citar pacote que o outro não tem.
describe "dados do jogo de referência" do
  def load(name) = YAML.safe_load_file(Rails.root.join("db/seeds/jogo", name))

  let(:packs) { load("pacotes.yml") }
  let(:availability) { load("disponibilidade.yml") }
  let(:rules) { %w[sempre dia nivel porcentagem_de_pacote porcentagem_do_total codigo todos_os_desafios qualquer pendente] }

  it "tem a regra de disponibilidade de cada pacote, e só deles" do
    _(availability.keys.sort).must_equal packs.pluck("nome").sort
  end

  it "usa só os tipos de regra conhecidos, e pacote citado existe" do
    all = availability.values.flat_map { |rule| [ rule, *rule["regras"] ] }

    _(all.pluck("regra").uniq - rules).must_be_empty
    _(all.filter_map { |rule| rule["pacote"] } - packs.pluck("nome")).must_be_empty
  end

  it "guarda a fonte e o preço de todo pacote" do
    _(packs.reject { |pack| pack["fonte"].is_a?(Integer) && pack["preco"].is_a?(Integer) }).must_be_empty
  end
end
