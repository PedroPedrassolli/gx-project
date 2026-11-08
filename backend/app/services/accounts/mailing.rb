module Accounts
  # Envia o e-mail na hora: a Vercel não tem fila de jobs (ADR 0008). Se o envio falhar,
  # registra no log e devolve false; a pessoa pode pedir de novo.
  module Mailing
    module_function

    def deliver(message)
      message.deliver_now
      true
    rescue StandardError => error
      Rails.logger.error("E-mail não enviado: #{error.class}: #{error.message}")
      false
    end
  end
end
