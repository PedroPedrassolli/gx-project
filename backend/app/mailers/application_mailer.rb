# Base dos e-mails: só texto, do remetente do projeto no Brevo (ADR 0004 e 0008).
class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "GX Project <nao-responda@gx-project.invalid>")
end
