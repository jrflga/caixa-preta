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

/// Faz o papel do `dwarfdump` e do `atos` e guarda os pedidos ao `atos`.
final class FerramentasFalsas {
    private(set) var pedidosAoAtos: [[String]] = []

    func rodar(_ programa: String, _ argumentos: [String]) -> String {
        switch argumentos.first {
        case "dwarfdump":
            return "UUID: AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE (arm64) \(argumentos.last ?? "")\n"
        case "atos":
            pedidosAoAtos.append(argumentos)
            // Endereço sem nome: o atos devolve o próprio endereço.
            return argumentos.last == "0x100000010"
                ? "SessaoDeExemplo.verificar() (in Exemplo) (SessaoDeExemplo.swift:147)\n"
                : "\(argumentos.last ?? "")\n"
        default:
            return ""
        }
    }
}

/// Uma pasta com um dSYM vazio de exemplo (o dwarfdump falso diz o UUID).
func dsymDeExemplo() -> URL {
    let pasta = pastaTemporaria()
    let dwarf = pasta.appending(path: "Exemplo.app.dSYM/Contents/Resources/DWARF", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: dwarf, withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: dwarf.appending(path: "Exemplo").path, contents: Data())
    return pasta
}
