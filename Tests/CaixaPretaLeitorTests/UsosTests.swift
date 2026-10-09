import ApoioDosTestes
@testable import CaixaPreta
import CaixaPretaLeitor
import Foundation
import Testing

@Suite("Usos do app")
struct UsosTests {
    @Test("classifica como cada uso terminou pela abertura seguinte")
    func finais() {
        let eventos = [
            evento("2026-10-09T10:00:00-03:00", "u1", "sessao.comecou", ["versao": "1.0", "build": "7", "ios": "27.0"]),
            evento("2026-10-09T10:05:00-03:00", "u2", "sessao.comecou"),
            evento("2026-10-09T10:05:00-03:00", "u2", "sessao.anterior", ["uso": "u1", "estado": "frente", "parada_ha_s": 5, "duracao_s": 295]),
            evento("2026-10-09T11:00:00-03:00", "u3", "sessao.comecou"),
            evento("2026-10-09T11:00:00-03:00", "u3", "sessao.anterior", ["uso": "u2", "estado": "fundo", "parada_ha_s": 120]),
            evento("2026-10-09T15:00:00-03:00", "u4", "sessao.comecou"),
            evento("2026-10-09T15:00:00-03:00", "u4", "sessao.anterior", ["uso": "u3", "estado": "fundo", "parada_ha_s": 7200]),
            evento("2026-10-09T15:10:00-03:00", "u5", "sessao.comecou"),
            evento("2026-10-09T15:10:00-03:00", "u5", "sessao.anterior", ["uso": "u4", "estado": "abrindo", "parada_ha_s": 600]),
        ]
        let usos = Usos.montar(eventos)
        #expect(usos.map(\.id) == ["u1", "u2", "u3", "u4", "u5"])
        #expect(usos.map(\.fim) == [
            .caiuNaFrente, .fechadoLogoNoFundo(voltouDepoisDe: 120), .fechadoNoFundo(voltouDepoisDe: 7200),
            .fechadoAntesDeAbrir, .semAberturaSeguinte,
        ])
        #expect(usos[0].versao == "1.0")
        #expect(usos[0].terminou == hora("2026-10-09T10:04:55-03:00"))
    }

    @Test("a falha que chega na abertura seguinte vai para o uso que caiu")
    func falhaNoUsoAnterior() {
        let eventos = [
            evento("2026-10-09T14:20:00-03:00", "u1", "sessao.comecou"),
            evento("2026-10-09T14:33:00-03:00", "u2", "sessao.comecou"),
            evento("2026-10-09T14:33:01-03:00", "u2", "ios.falha", ["tipo": "falha", "ate": "2026-10-09T17:31:00Z"]),
            // Relatório antigo, de antes do primeiro uso lido: fica onde chegou.
            evento("2026-10-09T14:33:02-03:00", "u2", "ios.falha", ["tipo": "travamento", "ate": "2026-10-08T12:00:00Z"]),
        ]
        let usos = Usos.montar(eventos)
        #expect(usos[0].falhas.map { $0.campos["tipo"] } == ["falha"])
        #expect(usos[1].falhas.map { $0.campos["tipo"] } == ["travamento"])
        #expect(!usos[1].eventos.contains { $0.nome == "ios.falha" })
    }

    @Test("o pico de memória junta os eventos do uso e o que a abertura seguinte contou")
    func pico() {
        let eventos = [
            evento("2026-10-09T10:00:00-03:00", "u1", "sessao.comecou", ["memoria_mb": 300]),
            evento("2026-10-09T10:01:00-03:00", "u1", "sessao.fundo", ["memoria_mb": 450]),
            evento("2026-10-09T10:02:00-03:00", "u2", "sessao.comecou", ["memoria_mb": 200]),
            evento("2026-10-09T10:02:00-03:00", "u2", "sessao.anterior", [
                "uso": "u1", "estado": "fundo", "parada_ha_s": 30, "memoria_mb": 700, "pico_mb": 980,
            ]),
        ]
        let usos = Usos.montar(eventos)
        #expect(usos[0].picoMB == 980)
        #expect(usos[1].picoMB == 200)
    }

    @Test("lê o arquivo do botão Enviar diagnóstico: eventos e relatórios")
    func arquivoEnviado() async throws {
        let caixa = caixaDeTeste(pasta: pastaTemporaria(), relogio: Relogio(hora("2026-10-09T12:00:00-03:00")))
        caixa.anotar("teste.passo")
        caixa.receberDiagnostico(ExemplosDoMetricKit.falha)
        let arquivo = try #require(await caixa.arquivoParaEnviar())
        let registros = Leitura.ler(arquivoEnviado: arquivo)
        #expect(registros.eventos.map(\.nome) == ["sessao.comecou", "teste.passo", "ios.falha"])
        let nome = try #require(registros.eventos.last?.campos["relatorio"]?.texto)
        #expect(registros.relatorios.keys.sorted() == [nome])
    }
}
