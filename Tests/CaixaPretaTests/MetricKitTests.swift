import ApoioDosTestes
@testable import CaixaPreta
import Foundation
import Testing

@Suite("Relatórios do MetricKit")
struct MetricKitTests {
    @Test("a falha vira ios.falha e o relatório cru fica guardado")
    func falha() throws {
        let pasta = pastaTemporaria()
        let caixa = caixaDeTeste(pasta: pasta)
        caixa.receberDiagnostico(ExemplosDoMetricKit.falha)
        caixa.esperar()
        let falha = try #require(eventos(em: pasta).first { $0.nome == "ios.falha" })
        let relatorio = try #require(falha.campos["relatorio"]?.texto)
        #expect(relatorio.hasPrefix("2026-10-09-diagnostico-"))
        #expect(falha.campos.filter { $0.key != "relatorio" } == [
            "tipo": "falha", "chave": "crashDiagnostics", "indice": 0, "sinal": 11, "excecao": 1, "codigo": 0,
            "motivo": "Namespace SIGNAL, Code 11 Segmentation fault: 11",
            "versao": "0.2.0", "build": "20261009.1513", "de": "2026-10-09T17:31:00Z", "ate": "2026-10-09T17:31:00Z",
        ])
        #expect(try Data(contentsOf: pasta.appending(path: "diagnosticos/\(relatorio).json")) == ExemplosDoMetricKit.falha)
    }

    @Test("o travamento leva a duração em milissegundos")
    func travamento() throws {
        let pasta = pastaTemporaria()
        let caixa = caixaDeTeste(pasta: pasta)
        caixa.receberDiagnostico(ExemplosDoMetricKit.travamento)
        caixa.esperar()
        let falha = try #require(eventos(em: pasta).first { $0.nome == "ios.falha" })
        #expect(falha.campos["tipo"] == "travamento")
        #expect(falha.campos["duracao_ms"] == 2500)
        #expect(LeituraDoMetricKit.milissegundos("830 ms") == 830)
        #expect(LeituraDoMetricKit.milissegundos("1.5 min") == 90_000)
    }

    @Test("o mesmo relatório entregue de novo, mesmo em outra abertura, é guardado e anotado uma vez")
    func repetido() throws {
        let pasta = pastaTemporaria()
        let primeira = caixaDeTeste(pasta: pasta)
        primeira.receberDiagnostico(ExemplosDoMetricKit.falha)
        primeira.receberDiagnostico(ExemplosDoMetricKit.falha)
        primeira.esperar()
        let segunda = caixaDeTeste(pasta: pasta)
        segunda.receberDiagnostico(ExemplosDoMetricKit.falha)
        segunda.esperar()
        #expect(eventos(em: pasta).filter { $0.nome == "ios.falha" }.count == 1)
        #expect(try FileManager.default.contentsOfDirectory(atPath: pasta.appending(path: "diagnosticos").path).count == 1)
    }

    @Test("a contagem diária de fechamentos só leva o que aconteceu")
    func fechamentos() {
        let pasta = pastaTemporaria()
        let caixa = caixaDeTeste(pasta: pasta)
        caixa.receberMetricas(ExemplosDoMetricKit.metricas)
        caixa.esperar()
        #expect(eventos(em: pasta).first { $0.nome == "ios.fechamentos" }?.campos == [
            "frente_acesso_invalido": 1, "fundo_normal": 5, "fundo_memoria_limite": 2,
            "de": "2026-10-08T03:00:00Z", "ate": "2026-10-09T02:59:00Z",
        ])
    }

    @Test("relatório que não é JSON, ou sem diagnóstico, não grava nada")
    func invalido() throws {
        let pasta = pastaTemporaria()
        let caixa = caixaDeTeste(pasta: pasta)
        caixa.receberDiagnostico(Data("x".utf8))
        caixa.receberDiagnostico(Data(#"{"crashDiagnostics":[]}"#.utf8))
        caixa.receberMetricas(Data("x".utf8))
        caixa.esperar()
        #expect(!eventos(em: pasta).contains { $0.nome.hasPrefix("ios.") })
        #expect(try FileManager.default.contentsOfDirectory(atPath: pasta.appending(path: "diagnosticos").path).isEmpty)
    }
}
