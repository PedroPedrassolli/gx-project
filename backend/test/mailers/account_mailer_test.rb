require "test_helper"

class AccountMailerTest < ActionMailer::TestCase
  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "13-17") }

  it "manda o link de confirmação do e-mail, que vale para o usuário" do
    mail = AccountMailer.email_verification(user)

    _(mail.to).must_equal [ "jaden@example.com" ]
    _(mail[:from].to_s).must_equal "GX Project <nao-responda@gx-project.invalid>"
    _(mail.subject).must_equal "Confirme seu e-mail no GX Project"
    _(mail.body.to_s).must_include "Olá, JadenYuki!"
    token = mail.body.to_s[%r{/verificar-email\?token=(\S+)}, 1]
    _(User.find_by_token_for(:email_verification, token)).must_equal user
  end

  it "manda o link de troca de senha, que vale para o usuário" do
    mail = AccountMailer.password_reset(user)

    _(mail.subject).must_equal "Troque sua senha do GX Project"
    _(mail.body.to_s).must_include "vale por 1 hora"
    token = mail.body.to_s[%r{/nova-senha\?token=(\S+)}, 1]
    _(User.find_by_password_reset_token(token)).must_equal user
  end
end
