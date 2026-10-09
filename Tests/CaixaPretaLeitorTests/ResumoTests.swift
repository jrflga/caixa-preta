import ApoioDosTestes
@testable import CaixaPreta
import CaixaPretaLeitor
import Foundation
import Testing

@Suite("Resumo")
struct ResumoTests {
    @Test("os quadros seguem a linha de execução culpada")
    func pilha() {
        #expect(Pilha.quadros(ExemplosDoMetricKit.falha, chave: "crashDiagnostics", indice: 0) == [
            Quadro(binario: "Exemplo", uuid: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", deslocamento: 16),
            Quadro(binario: "Exemplo", uuid: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", deslocamento: 32),
            Quadro(binario: "WebKit", uuid: "12121212-3434-5656-7878-909090909090", deslocamento: 1024),
        ])
        #expect(Pilha.quadros(ExemplosDoMetricKit.falha, chave: "crashDiagnostics", indice: 1).isEmpty)
    }

    @Test("o atos recebe o dSYM certo e o endereço a partir de 0x100000000")
    func simbolizador() {
        let ferramentas = FerramentasFalsas()
        let simbolizador = Simbolizador(pastas: [dsymDeExemplo()], rodar: ferramentas.rodar)
        let quadro = Quadro(binario: "Exemplo", uuid: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", deslocamento: 16)
        #expect(simbolizador.nome(quadro) == "SessaoDeExemplo.verificar() (in Exemplo) (SessaoDeExemplo.swift:147)")
        let pedido = ferramentas.pedidosAoAtos.first ?? []
        #expect(pedido.first == "atos")
        #expect(pedido.dropFirst().first == "-o")
        #expect(pedido.dropFirst(2).first?.hasSuffix("Exemplo.app.dSYM/Contents/Resources/DWARF/Exemplo") == true)
        #expect(Array(pedido.suffix(5)) == ["-arch", "arm64", "-l", "0x100000000", "0x100000010"])
        #expect(simbolizador.nome(Quadro(binario: "WebKit", uuid: "12121212-3434-5656-7878-909090909090", deslocamento: 1024)) == nil)
    }

    @Test("o resumo conta como o uso terminou, a memória, os problemas e a falha com a pilha")
    func resumo() {
        let pasta = pastaTemporaria()
        let relogio = Relogio(hora("2026-10-09T14:20:00-03:00"))
        let memoria = Compartilhado(300)
        let primeira = caixaDeTeste(pasta: pasta, relogio: relogio, memoria: memoria)
        primeira.mudouDeEstado("frente")
        primeira.esperar()
        relogio.avancar(300)
        primeira.anotar("pagina.situacao", ["site": "loja", "situacao": "erro_na_pagina"])
        primeira.anotar("pagina.reaberta", ["site": "loja", "vezes": 1])
        primeira.esperar()
        relogio.avancar(360)
        memoria.valor = 612
        primeira.mudouDeEstado("fundo")
        primeira.esperar()
        relogio.avancar(120)
        let segunda = caixaDeTeste(pasta: pasta, relogio: relogio, memoria: memoria)
        segunda.receberDiagnostico(ExemplosDoMetricKit.falha)
        segunda.receberMetricas(ExemplosDoMetricKit.metricas)
        segunda.esperar()
        let texto = Resumo.texto(
            titulo: "Exemplo · aparelho abcd1234-iPhone15,4",
            registros: Leitura.ler(pasta: pasta),
            simbolizador: Simbolizador(pastas: [dsymDeExemplo()], rodar: FerramentasFalsas().rodar),
            fuso: calendarioDosTestes.timeZone
        )
        let esperadas = [
            "Exemplo · aparelho abcd1234-iPhone15,4\n",
            "Uso \(primeira.uso) · 09/10 14:20:00 → 14:31:00 (11 min) · versão 1.0 (7) · iOS 27.0",
            "  Como terminou: fechado logo depois de ir para o fundo; abriu de novo 2 min depois do último sinal.",
            "  Memória: pico 612 MB.",
            "  Eventos: pagina.reaberta 1 · pagina.situacao 1",
            "  Problemas:\n    14:25:00 pagina.situacao site=loja situacao=erro_na_pagina",
            "  Falha do iOS: falha · sinal 11 (SIGSEGV: acesso inválido à memória) · exceção EXC_BAD_ACCESS"
                + " · motivo: Namespace SIGNAL, Code 11 Segmentation fault: 11 · relatório de 14:31:00 a 14:31:00"
                + " · versão 0.2.0 (20261009.1513)",
            "    0  Exemplo  SessaoDeExemplo.verificar() (in Exemplo) (SessaoDeExemplo.swift:147)",
            "    1  Exemplo  +0x20",
            "    2  WebKit  +0x400",
            "  Últimos passos:",
            "    14:31:00 sessao.fundo memoria_mb=612",
            "Uso \(segunda.uso) · 09/10 14:33:00",
            "  Como terminou: sem abertura seguinte (ainda aberto, ou fechado e não aberto de novo).",
            "Fechamentos contados pelo iOS (08/10 00:00:00 → 08/10 23:59:00): na frente: acesso inválido 1;"
                + " no fundo: memória (limite) 2, normal 5.",
        ]
        for linha in esperadas {
            #expect(texto.contains(linha), "Faltou: \(linha)\n\(texto)")
        }
        #expect(!texto.contains("sessao.anterior"))
    }
}
