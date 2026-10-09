import ApoioDosTestes
@testable import CaixaPreta
import Foundation

/// Uma caixa com hora e memória inventadas, sem pulso, já começada.
func caixaDeTeste(
    pasta: URL = pastaTemporaria(),
    relogio: Relogio = Relogio(hora("2026-10-09T12:00:00-03:00")),
    memoria: Compartilhado<Int> = Compartilhado(300),
    limiteDoDia: Int = 5_000_000
) -> Caixa {
    let ambiente = Ambiente(
        app: "Exemplo", versao: "1.0", build: "7", ios: "27.0", modelo: "iPhone15,4",
        agora: { relogio.agora }, memoriaEmMB: { memoria.valor }
    )
    let caixa = Caixa(pasta: pasta, ambiente: ambiente, calendario: calendarioDosTestes, limiteDoDia: limiteDoDia)
    caixa.comecar(intervaloDoPulso: nil)
    return caixa
}

/// Todos os eventos gravados na pasta, dia a dia, na ordem do arquivo.
func eventos(em pasta: URL) -> [Evento] {
    let nomes = ((try? FileManager.default.contentsOfDirectory(atPath: pasta.path)) ?? [])
        .filter { $0.hasSuffix(".jsonl") }
        .sorted()
    return nomes.flatMap { nome in
        ((try? Data(contentsOf: pasta.appending(path: nome))) ?? Data())
            .split(separator: 0x0A)
            .compactMap { Linha.decodificar(Data($0)) }
    }
}
