import ApoioDosTestes
@testable import CaixaPreta
import Foundation

/// Uma caixa de verdade gravando na pasta, com hora e memória inventadas.
func caixaDeTeste(pasta: URL, relogio: Relogio, memoria: Compartilhado<Int> = Compartilhado(300)) -> Caixa {
    let ambiente = Ambiente(
        app: "Exemplo", versao: "1.0", build: "7", ios: "27.0", modelo: "iPhone15,4",
        agora: { relogio.agora }, memoriaEmMB: { memoria.valor }
    )
    let caixa = Caixa(pasta: pasta, ambiente: ambiente, calendario: calendarioDosTestes)
    caixa.comecar(intervaloDoPulso: nil)
    return caixa
}

func evento(_ quando: String, _ uso: String, _ nome: String, _ campos: [String: Valor] = [:]) -> Evento {
    Evento(hora: hora(quando), uso: uso, nome: nome, campos: campos)
}
