import ApoioDosTestes
@testable import CaixaPreta
import Foundation
import Testing

@Suite("Caixa")
struct CaixaTests {
    @Test("sessao.comecou leva o app, a versão, o aparelho e a memória")
    func comecou() {
        let pasta = pastaTemporaria()
        let caixa = caixaDeTeste(pasta: pasta)
        caixa.esperar()
        let primeiro = eventos(em: pasta).first
        #expect(primeiro?.nome == "sessao.comecou")
        #expect(primeiro?.uso == caixa.uso)
        #expect(primeiro?.campos == [
            "app": "Exemplo", "versao": "1.0", "build": "7", "ios": "27.0", "modelo": "iPhone15,4", "memoria_mb": 300,
        ])
        #expect(caixa.uso.wholeMatch(of: /[0-9a-f]{8}/) != nil)
        // O código do aparelho fica: a abertura seguinte usa o mesmo.
        #expect(caixaDeTeste(pasta: pasta).aparelho == caixa.aparelho)
    }

    @Test("a segunda abertura conta como terminou a primeira")
    func duasAberturas() {
        let pasta = pastaTemporaria()
        let relogio = Relogio(hora("2026-10-09T12:00:00-03:00"))
        let memoria = Compartilhado(300)
        let primeira = caixaDeTeste(pasta: pasta, relogio: relogio, memoria: memoria)
        primeira.mudouDeEstado("frente")
        primeira.esperar()
        relogio.avancar(60)
        memoria.valor = 512
        primeira.mudouDeEstado("fundo")
        primeira.esperar()
        relogio.avancar(120)
        let segunda = caixaDeTeste(pasta: pasta, relogio: relogio, memoria: memoria)
        segunda.esperar()
        let todos = eventos(em: pasta)
        #expect(todos.filter { $0.uso == primeira.uso }.map(\.nome) == ["sessao.comecou", "sessao.frente", "sessao.fundo"])
        let anterior = todos.first { $0.nome == "sessao.anterior" }
        #expect(anterior?.uso == segunda.uso)
        #expect(anterior?.campos == [
            "uso": .texto(primeira.uso), "estado": "fundo", "duracao_s": 60, "parada_ha_s": 120, "memoria_mb": 512, "pico_mb": 512,
        ])
    }

    @Test("primeira abertura e marcador estragado: sem sessao.anterior e sem queda")
    func semAnterior() throws {
        let pasta = pastaTemporaria()
        caixaDeTeste(pasta: pasta).esperar()
        #expect(!eventos(em: pasta).contains { $0.nome == "sessao.anterior" })
        try Data("{".utf8).write(to: pasta.appending(path: "uso-atual.json"))
        let segunda = caixaDeTeste(pasta: pasta)
        segunda.esperar()
        #expect(!eventos(em: pasta).contains { $0.nome == "sessao.anterior" })
        // O marcador volta a valer: a terceira abertura vê a segunda.
        caixaDeTeste(pasta: pasta).esperar()
        #expect(eventos(em: pasta).last { $0.nome == "sessao.anterior" }?.campos["uso"] == .texto(segunda.uso))
    }

    @Test("repetir o estado não grava de novo")
    func estadoRepetido() {
        let pasta = pastaTemporaria()
        let caixa = caixaDeTeste(pasta: pasta)
        for estado in ["frente", "frente", "fundo", "fundo", "frente"] { caixa.mudouDeEstado(estado) }
        caixa.esperar()
        #expect(eventos(em: pasta).map(\.nome) == ["sessao.comecou", "sessao.frente", "sessao.fundo", "sessao.frente"])
    }

    @Test("o aviso de memória do iOS grava a memória da hora")
    func avisoDeMemoria() {
        let pasta = pastaTemporaria()
        let memoria = Compartilhado(300)
        let caixa = caixaDeTeste(pasta: pasta, memoria: memoria)
        caixa.esperar()
        memoria.valor = 1400
        caixa.avisoDeMemoria()
        caixa.esperar()
        #expect(eventos(em: pasta).last?.nome == "sessao.aviso_de_memoria")
        #expect(eventos(em: pasta).last?.campos == ["memoria_mb": 1400])
    }

    @Test("o pulso guarda a última memória e a mais alta para a próxima abertura, sem linha no arquivo")
    func pulso() {
        let pasta = pastaTemporaria()
        let relogio = Relogio(hora("2026-10-09T12:00:00-03:00"))
        let memoria = Compartilhado(300)
        let primeira = caixaDeTeste(pasta: pasta, relogio: relogio, memoria: memoria)
        primeira.esperar()
        memoria.valor = 900
        relogio.avancar(30)
        primeira.pulsar()
        primeira.esperar()
        memoria.valor = 400
        relogio.avancar(30)
        primeira.pulsar()
        primeira.esperar()
        relogio.avancar(10)
        caixaDeTeste(pasta: pasta, relogio: relogio, memoria: memoria).esperar()
        let todos = eventos(em: pasta)
        #expect(todos.first { $0.nome == "sessao.anterior" }?.campos == [
            "uso": .texto(primeira.uso), "estado": "abrindo", "duracao_s": 60, "parada_ha_s": 10, "memoria_mb": 400, "pico_mb": 900,
        ])
        #expect(todos.filter { $0.uso == primeira.uso }.map(\.nome) == ["sessao.comecou"])
    }

    @Test("o recusado vira caixa.recusado e o valor não chega ao arquivo")
    func recusado() throws {
        let pasta = pastaTemporaria()
        let caixa = caixaDeTeste(pasta: pasta)
        caixa.anotar("contato.novo", ["telefone": "(21) 99999-0000"])
        caixa.anotar("Cliente Teste")
        caixa.esperar()
        #expect(eventos(em: pasta).filter { $0.nome == "caixa.recusado" }.map(\.campos) == [
            ["evento": "contato.novo", "campo": "telefone"], ["evento": "invalido", "campo": "nome"],
        ])
        let bruto = try String(contentsOf: pasta.appending(path: "2026-10-09.jsonl"), encoding: .utf8)
        #expect(!bruto.contains("99999"))
        #expect(!bruto.contains("Cliente"))
    }

    @Test("mil anotações de várias tarefas ao mesmo tempo: nenhuma perdida ou misturada")
    func muitasAoMesmoTempo() async throws {
        let pasta = pastaTemporaria()
        let caixa = caixaDeTeste(pasta: pasta)
        await withTaskGroup(of: Void.self) { grupo in
            for numero in 0..<1000 {
                grupo.addTask { _ = caixa.anotar("teste.passo", ["n": .inteiro(numero)]) }
            }
        }
        caixa.esperar()
        let bruto = try String(contentsOf: pasta.appending(path: "2026-10-09.jsonl"), encoding: .utf8)
        let lidos = eventos(em: pasta)
        #expect(bruto.split(separator: "\n").count == lidos.count)
        let numeros = lidos.filter { $0.nome == "teste.passo" }.compactMap { $0.campos["n"]?.inteiro }
        #expect(numeros.count == 1000)
        #expect(Set(numeros) == Set(0..<1000))
    }

    @Test("passado o limite do dia, caixa.limite entra uma vez")
    func limite() {
        let pasta = pastaTemporaria()
        let caixa = caixaDeTeste(pasta: pasta, limiteDoDia: 300)
        for _ in 0..<10 { caixa.anotar("teste.passo") }
        caixa.esperar()
        #expect(eventos(em: pasta).filter { $0.nome == "caixa.limite" }.count == 1)
    }

    @Test("a captura só vê o que roda na própria tarefa, já filtrado")
    func captura() async {
        async let primeira = CaixaPreta.capturando { CaixaPreta.anotar("teste.a") }
        async let segunda = CaixaPreta.capturando {
            CaixaPreta.anotar("teste.b")
            CaixaPreta.anotar("Teste C")
        }
        let (a, b) = await (primeira, segunda)
        #expect(a.map(\.nome) == ["teste.a"])
        #expect(b.map(\.nome) == ["teste.b", "caixa.recusado"])
    }
}
