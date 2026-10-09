import ApoioDosTestes
@testable import CaixaPreta
import Foundation
import Testing

@Suite("Cópia para o iCloud e arquivo para enviar")
struct EspelhoTests {
    @Test("ao ir para o fundo, o dia e os relatórios vão para a pasta do aparelho no iCloud")
    func copiaNoFundo() throws {
        let pasta = pastaTemporaria()
        let icloud = pastaTemporaria()
        let caixa = caixaDeTeste(pasta: pasta, espelho: Espelho(acharRaiz: { icloud }))
        caixa.anotar("teste.passo", ["n": 1])
        caixa.receberDiagnostico(ExemplosDoMetricKit.falha)
        caixa.mudouDeEstado("fundo")
        caixa.esperar()
        let destino = icloud.appending(path: "Documents/CaixaPreta/\(caixa.aparelho)-iPhone15,4", directoryHint: .isDirectory)
        let copiado = try Data(contentsOf: destino.appending(path: "2026-10-09.jsonl"))
        let original = try Data(contentsOf: pasta.appending(path: "2026-10-09.jsonl"))
        #expect(copiado == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath: destino.appending(path: "diagnosticos").path).count == 1)
    }

    @Test("a tarefa de fundo só termina depois da cópia")
    func depoisDaCopia() {
        let icloud = pastaTemporaria()
        let caixa = caixaDeTeste(espelho: Espelho(acharRaiz: { icloud }))
        let destino = icloud.appending(path: "Documents/CaixaPreta/\(caixa.aparelho)-iPhone15,4/2026-10-09.jsonl")
        // A abertura já copiou o arquivo; a cópia do fundo traz o sessao.fundo.
        let copiadoAntesDoFim = Compartilhado<Bool?>(nil)
        caixa.mudouDeEstado("fundo") {
            copiadoAntesDoFim.valor = (try? String(contentsOf: destino, encoding: .utf8))?.contains("sessao.fundo")
        }
        caixa.esperar()
        #expect(copiadoAntesDoFim.valor == true)
    }

    @Test("sem iCloud, tudo fica no aparelho e caixa.sem_icloud entra uma vez")
    func semICloud() {
        let pasta = pastaTemporaria()
        let caixa = caixaDeTeste(pasta: pasta, espelho: Espelho(acharRaiz: { nil }))
        for estado in ["fundo", "frente", "fundo"] { caixa.mudouDeEstado(estado) }
        caixa.esperar()
        let nomes = eventos(em: pasta).map(\.nome)
        #expect(nomes.filter { $0 == "caixa.sem_icloud" }.count == 1)
        #expect(nomes.filter { $0 == "sessao.fundo" }.count == 2)
    }

    @Test("no iCloud, o que passou de 14 dias é apagado")
    func guardaNoICloud() throws {
        let pasta = pastaTemporaria()
        let icloud = pastaTemporaria()
        try Data("abcd1234".utf8).write(to: pasta.appending(path: "aparelho.txt"))
        let destino = icloud.appending(path: "Documents/CaixaPreta/abcd1234-iPhone15,4", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: destino, withIntermediateDirectories: true)
        for nome in ["2026-09-25.jsonl", "2026-09-26.jsonl"] {
            FileManager.default.createFile(atPath: destino.appending(path: nome).path, contents: Data("x".utf8))
        }
        caixaDeTeste(pasta: pasta, espelho: Espelho(acharRaiz: { icloud })).esperar()
        let restam = Set(try FileManager.default.contentsOfDirectory(atPath: destino.path))
        #expect(restam == ["2026-09-26.jsonl", "2026-10-09.jsonl", "diagnosticos"])
    }

    @Test("o arquivo para enviar junta os últimos 3 dias e os relatórios deles")
    func arquivoParaEnviar() async throws {
        let relogio = Relogio(hora("2026-10-06T12:00:00-03:00"))
        let caixa = caixaDeTeste(relogio: relogio)
        for dia in 0..<4 {
            if dia > 0 { relogio.avancar(86_400) }
            caixa.anotar("teste.dia")
        }
        caixa.receberDiagnostico(ExemplosDoMetricKit.falha)
        let arquivo = try #require(await caixa.arquivoParaEnviar())
        #expect(arquivo.lastPathComponent == "CaixaPreta-Exemplo-\(caixa.aparelho)-iPhone15,4-2026-10-09.jsonl")
        let linhas = try Data(contentsOf: arquivo).split(separator: 0x0A).map { Data($0) }
        let lidos = linhas.compactMap(Linha.decodificar)
        #expect(lidos.filter { $0.nome == "teste.dia" }.map { Dia.nome($0.hora, calendario: calendarioDosTestes) } == [
            "2026-10-07", "2026-10-08", "2026-10-09",
        ])
        #expect(!lidos.contains { $0.nome == "sessao.comecou" })
        let relatorios = linhas.compactMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] }
            .filter { $0["diagnostico"] != nil }
        #expect(relatorios.count == 1)
        #expect((relatorios.first?["json"] as? [String: Any])?["crashDiagnostics"] != nil)
    }
}
