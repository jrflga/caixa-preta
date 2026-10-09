import ApoioDosTestes
@testable import CaixaPreta
import CaixaPretaFormato
import Foundation
import Testing

private func evento(_ quando: String, _ nome: String = "teste.passo") -> Evento {
    Evento(hora: hora(quando), uso: "u1", nome: nome)
}

private func linhas(_ arquivo: URL) -> [Evento] {
    ((try? Data(contentsOf: arquivo)) ?? Data()).split(separator: 0x0A).compactMap { Linha.decodificar(Data($0)) }
}

@Suite("Diário no aparelho")
struct DiarioTests {
    @Test("a virada do dia abre um arquivo novo")
    func viradaDoDia() {
        let diario = Diario(pasta: pastaTemporaria(), calendario: calendarioDosTestes)
        diario.gravar(evento("2026-10-09T23:59:59-03:00"), doApp: true)
        diario.gravar(evento("2026-10-10T00:00:01-03:00"), doApp: true)
        #expect(linhas(diario.arquivo(doDia: "2026-10-09")).count == 1)
        #expect(linhas(diario.arquivo(doDia: "2026-10-10")).count == 1)
        #expect(diario.tirarDiasParaCopiar().map(\.lastPathComponent) == ["2026-10-09.jsonl", "2026-10-10.jsonl"])
        #expect(diario.tirarDiasParaCopiar().isEmpty)
    }

    @Test("passado o limite do dia, só os eventos da caixa entram; no dia seguinte, volta")
    func limiteDoDia() {
        let pasta = pastaTemporaria()
        let diario = Diario(pasta: pasta, calendario: calendarioDosTestes, limiteDoDia: 300)
        let resultados = (0..<10).map { _ in diario.gravar(evento("2026-10-09T12:00:00-03:00"), doApp: true) }
        #expect(resultados.first == .gravado)
        #expect(resultados.last == .acimaDoLimite)
        #expect(diario.gravar(evento("2026-10-09T12:00:01-03:00", "sessao.fundo"), doApp: false) == .gravado)
        #expect(linhas(diario.arquivo(doDia: "2026-10-09")).last?.nome == "sessao.fundo")
        // Uma abertura nova no mesmo dia continua contando do tamanho do arquivo.
        let reaberto = Diario(pasta: pasta, calendario: calendarioDosTestes, limiteDoDia: 300)
        #expect(reaberto.gravar(evento("2026-10-09T13:00:00-03:00"), doApp: true) == .acimaDoLimite)
        #expect(reaberto.gravar(evento("2026-10-10T08:00:00-03:00"), doApp: true) == .gravado)
    }

    @Test("guarda 14 dias: hoje e os 13 anteriores, aqui e nos relatórios")
    func guarda() throws {
        let pasta = pastaTemporaria()
        let diario = Diario(pasta: pasta, calendario: calendarioDosTestes)
        for nome in ["2026-09-25.jsonl", "2026-09-26.jsonl", "uso-atual.json", "aparelho.txt"] {
            FileManager.default.createFile(atPath: pasta.appending(path: nome).path, contents: Data("x".utf8))
        }
        for nome in ["2026-09-25-diagnostico-aaaa.json", "2026-09-26-diagnostico-bbbb.json"] {
            FileManager.default.createFile(atPath: diario.pastaDosRelatorios.appending(path: nome).path, contents: Data("{}".utf8))
        }
        diario.limparAntigos(hoje: hora("2026-10-09T12:00:00-03:00"))
        #expect(diario.primeiroDiaGuardado(hoje: hora("2026-10-09T12:00:00-03:00")) == "2026-09-26")
        let restam = Set(try FileManager.default.contentsOfDirectory(atPath: pasta.path))
        #expect(restam == ["2026-09-26.jsonl", "uso-atual.json", "aparelho.txt", "diagnosticos"])
        #expect(try FileManager.default.contentsOfDirectory(atPath: diario.pastaDosRelatorios.path) == ["2026-09-26-diagnostico-bbbb.json"])
    }

    @Test("o mesmo relatório guardado duas vezes fica uma vez")
    func relatorioRepetido() throws {
        let diario = Diario(pasta: pastaTemporaria(), calendario: calendarioDosTestes)
        let json = Data(#"{"crashDiagnostics":[]}"#.utf8)
        let nome = diario.guardarRelatorio(json, tipo: "diagnostico", hoje: hora("2026-10-09T12:00:00-03:00"))
        #expect(nome?.hasPrefix("2026-10-09-diagnostico-") == true)
        #expect(diario.guardarRelatorio(json, tipo: "diagnostico", hoje: hora("2026-10-10T12:00:00-03:00")) == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: diario.pastaDosRelatorios.path).count == 1)
    }
}
