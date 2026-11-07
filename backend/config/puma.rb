# Configuração do Puma (servidor web do Rails).
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

port ENV.fetch("PORT", 3000)

plugin :tmp_restart

# A Vercel desliga o container quando ele fica ocioso (SIGTERM). Sem isto, o Puma
# termina o que estava fazendo e depois levanta uma exceção, e o processo sai com
# código 1: a Vercel registra cada desligamento normal como um erro.
raise_exception_on_sigterm false

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
