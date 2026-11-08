# Base dos e-mails: só texto, do remetente do projeto no Brevo (ADR 0004 e 0008). O
# MAIL_FROM é só o endereço; o nome "GX Project" vem daqui.
class ApplicationMailer < ActionMailer::Base
  default from: -> { email_address_with_name(ENV.fetch("MAIL_FROM", "nao-responda@gx-project.invalid"), "GX Project") }
end
