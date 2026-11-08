import { Link } from "react-router";

// Termos de uso e política de privacidade (GXP-40), aprovados pelo Pedro em 08/11/2026.
// Mudou o texto? Troque a data da versão e avise no site, como os próprios textos prometem.
export const LEGAL_VERSION = "08/11/2026";
export const CONTACT_EMAIL = "pedropedrassolli@outlook.com";
// A AGPL pede que quem usa o site pela rede consiga baixar o código-fonte.
export const SOURCE_URL = "https://github.com/PedroPedrassolli/gx-project";

// O que guardamos de cada jogador e para quê (precisa bater com o Accounts::DataExport).
const STORED_DATA = [
  ["E-mail", "Entrar, confirmar a conta e trocar a senha"],
  ["Senha", "Entrar. Guardamos só um resumo criptográfico (bcrypt), nunca a senha"],
  ["Apelido", "Mostrar você para os outros jogadores"],
  [
    "Faixa de idade (13 a 17 ou 18+)",
    "Cumprir a idade mínima. A data de nascimento serve só para calcular a faixa e não é guardada",
  ],
  [
    "Datas de criação da conta, do aceite dos termos e desta política, de confirmação do e-mail e de cada login",
    "Funcionar e manter a conta segura. Não guardamos IP nem navegador do login",
  ],
  ["Coleção e decks", "O jogo em si"],
];

function Email() {
  return <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>;
}

function Version() {
  return <p className="hint">Versão de {LEGAL_VERSION}.</p>;
}

export function TermsPage() {
  return (
    <main className="page legal">
      <h1>Termos de uso</h1>
      <Version />
      <ol>
        <li>
          <strong>O que é o GX Project.</strong> Um projeto de fã, sem fins lucrativos, para jogar
          duelos de cartas online. O código é aberto (AGPL-3.0) e está no{" "}
          <a href={SOURCE_URL}>GitHub</a>. Não temos ligação com a Konami nem aprovação dela;
          Yu-Gi-Oh! é marca registrada da Konami. Os dados das cartas vêm da Yugipedia (CC BY-SA) e
          as imagens, do YGOPRODeck.
        </li>
        <li>
          <strong>Quem pode criar conta.</strong> Quem tem 13 anos ou mais. Quem tem menos de 18
          deve usar com o conhecimento dos pais ou responsáveis. Uma conta por pessoa, com dados
          verdadeiros. Cuidar da senha é com você.
        </li>
        <li>
          <strong>Como se comportar.</strong> Apelido sem palavrão nem ofensa. Nada de trapaça, de
          explorar falha do jogo (se achar uma, avise) ou de usar programa para jogar por você.
          Podemos suspender ou apagar a conta de quem descumprir estas regras.
        </li>
        <li>
          <strong>Cartas, DP e pacotes.</strong> Tudo no jogo é virtual, não vale dinheiro e não
          pode ser vendido nem trocado fora do jogo. Como o projeto está em construção, regras,
          cartas e saldos podem mudar ou ser reiniciados.
        </li>
        <li>
          <strong>Sem garantia.</strong> O site é oferecido como está: pode sair do ar, mudar ou
          acabar, e dados podem se perder. Não cobramos nada e não prometemos funcionamento
          contínuo.
        </li>
        <li>
          <strong>Mudanças.</strong> Quando estes termos mudarem, avisamos no site. Continuar usando
          depois do aviso é aceitar a versão nova.
        </li>
        <li>
          <strong>Contato.</strong> <Email />.
        </li>
      </ol>
      <p>
        Veja também a <Link to="/privacidade">Política de privacidade</Link>.
      </p>
    </main>
  );
}

export function PrivacyPage() {
  return (
    <main className="page legal">
      <h1>Política de privacidade</h1>
      <Version />

      <h2>Quem cuida dos seus dados</h2>
      <p>
        Pedro Pedrassolli, mantenedor do GX Project, é o controlador dos dados (LGPD). Contato:{" "}
        <Email />.
      </p>

      <h2>O que guardamos e por quê</h2>
      <table>
        <thead>
          <tr>
            <th scope="col">Dado</th>
            <th scope="col">Para quê</th>
          </tr>
        </thead>
        <tbody>
          {STORED_DATA.map(([data, purpose]) => (
            <tr key={data}>
              <td>{data}</td>
              <td>{purpose}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <p>
        A base legal é a execução do serviço que você pediu ao criar a conta (art. 7º, V) e, para a
        segurança, o legítimo interesse (art. 7º, IX).
      </p>

      <h2>Segurança</h2>
      <p>
        Para frear quem tenta adivinhar senhas, contamos as tentativas de login, cadastro e troca de
        senha por e-mail e por endereço IP. Esses contadores somem em até 1 hora. A hospedagem
        também registra os acessos (IP e navegador) por pouco tempo, para manter o site no ar. Todo
        o site usa HTTPS.
      </p>

      <h2>Cookies</h2>
      <p>
        Só os necessários: um para manter você logado (<code>session_id</code>) e um de segurança
        contra ataques de outros sites (<code>_gx_session</code>). Não usamos cookie de propaganda
        nem de estatística. O navegador também guarda a língua escolhida para o texto das cartas.
      </p>

      <h2>Com quem os dados ficam</h2>
      <p>
        Usamos serviços de terceiros, que tratam os dados só para nos atender: Vercel (hospedagem,
        com servidor em São Paulo), Supabase (banco de dados, em São Paulo), Brevo (envio de
        e-mail), GitHub (cópia de segurança criptografada) e Cloudflare (imagens das cartas, sem
        dado de conta). Algumas dessas empresas ficam fora do Brasil, o que é uma transferência
        internacional de dados (art. 33). Não vendemos dados nem usamos para propaganda.
      </p>

      <h2>Por quanto tempo</h2>
      <p>
        Enquanto a conta existir. Ao excluir a conta, apagamos na hora a conta, a coleção e os
        decks. Uma vez por semana fazemos uma cópia de segurança criptografada do banco, que fica
        guardada por 30 dias: o que você apagar some também das cópias em até 30 dias.
      </p>

      <h2>Seus direitos (art. 18)</h2>
      <p>
        Em <Link to="/conta">Minha conta</Link> você baixa todos os seus dados (num arquivo JSON) e
        exclui a conta. Para corrigir um dado, tirar uma dúvida ou fazer outro pedido, escreva para{" "}
        <Email />.
      </p>

      <h2>Crianças e adolescentes</h2>
      <p>
        O cadastro é a partir dos 13 anos. Pedimos o mínimo de dados e não mostramos propaganda.
      </p>

      <h2>Mudanças</h2>
      <p>Quando esta política mudar, avisamos no site.</p>
      <p>
        Veja também os <Link to="/termos">Termos de uso</Link>.
      </p>
    </main>
  );
}
