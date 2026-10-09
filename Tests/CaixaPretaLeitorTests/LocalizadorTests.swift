import ApoioDosTestes
@testable import CaixaPreta
import CaixaPretaLeitor
import Foundation
import Testing

@Suite("Localizador no Mac")
struct LocalizadorTests {
    @Test("acha a pasta do app entre os containers e baixa o que o iCloud não baixou")
    func achaEBaixa() throws {
        let raiz = pastaTemporaria()
        let doApp = raiz.appending(path: "iCloud~app~exemplo/Documents/CaixaPreta/abcd1234-iPhone15,4", directoryHint: .isDirectory)
        let deOutro = raiz.appending(path: "iCloud~app~outro/Documents/CaixaPreta/ef567890-iPhone16,1", directoryHint: .isDirectory)
        for pasta in [doApp, deOutro] {
            try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        }
        // Só o marcador do iCloud: o arquivo de verdade ainda não desceu.
        FileManager.default.createFile(atPath: doApp.appending(path: ".2026-10-09.jsonl.icloud").path, contents: Data())
        try Linha.codificar(evento("2026-10-09T12:00:00-03:00", "u9", "sessao.comecou", ["app": "Outro"]))
            .write(to: deOutro.appending(path: "2026-10-09.jsonl"))
        let pedidos = Compartilhado<[String]>([])
        let achadas = Localizador.pastas(doApp: "Exemplo", raiz: raiz) { arquivo in
            pedidos.valor.append(arquivo.lastPathComponent)
            try? Linha.codificar(evento("2026-10-09T12:00:00-03:00", "u1", "sessao.comecou", ["app": "Exemplo"])).write(to: arquivo)
        }
        #expect(achadas.map(\.lastPathComponent) == ["abcd1234-iPhone15,4"])
        #expect(pedidos.valor == ["2026-10-09.jsonl"])
    }

    @Test("sem iCloud Drive no Mac, nenhuma pasta")
    func semRaiz() {
        #expect(Localizador.pastas(doApp: "Exemplo", raiz: pastaTemporaria().appending(path: "nao-existe")) { _ in }.isEmpty)
    }
}
