import ApoioDosTestes
@testable import CaixaPreta
import CaixaPretaLeitor
import Foundation
import Testing

@Suite("Comando")
struct ComandoTests {
    private func contexto(raiz: URL) -> Contexto {
        var contexto = Contexto()
        contexto.raiz = raiz
        contexto.agora = hora("2026-10-09T18:00:00-03:00")
        contexto.fuso = calendarioDosTestes.timeZone
        contexto.baixar = { _ in }
        contexto.rodar = FerramentasFalsas().rodar
        contexto.arquivosDoXcode = pastaTemporaria()
        return contexto
    }

    private func rodar(_ argumentos: [String], _ contexto: Contexto) -> (codigo: Int32, saida: String) {
        var saida = ""
        let codigo = Comando.rodar(argumentos, contexto: contexto) { saida += $0 }
        return (codigo, saida)
    }

    @Test("eventos de um uso desde uma hora")
    func eventos() {
        let raiz = pastaTemporaria()
        let pasta = raiz.appending(path: "iCloud~app~exemplo/Documents/CaixaPreta/abcd1234-iPhone15,4", directoryHint: .isDirectory)
        let relogio = Relogio(hora("2026-10-09T14:20:00-03:00"))
        let caixa = caixaDeTeste(pasta: pasta, relogio: relogio)
        caixa.anotar("teste.cedo")
        relogio.avancar(900)
        caixa.anotar("teste.tarde", ["n": 2])
        caixa.esperar()
        let resultado = rodar(["eventos", "Exemplo", "--uso", caixa.uso, "--desde", "14:30"], contexto(raiz: raiz))
        #expect(resultado.codigo == 0)
        #expect(resultado.saida == "Exemplo · aparelho abcd1234-iPhone15,4\n09/10 14:35:00 \(caixa.uso) teste.tarde n=2\n")
    }

    @Test("resumo pelo arquivo enviado")
    func resumoDoArquivo() async throws {
        let caixa = caixaDeTeste(pasta: pastaTemporaria(), relogio: Relogio(hora("2026-10-09T14:20:00-03:00")))
        let arquivo = try #require(await caixa.arquivoParaEnviar())
        let resultado = rodar(["resumo", "Exemplo", "--arquivo", arquivo.path], contexto(raiz: pastaTemporaria()))
        #expect(resultado.codigo == 0)
        #expect(resultado.saida.hasPrefix(arquivo.lastPathComponent + "\n"))
        #expect(resultado.saida.contains("Uso \(caixa.uso) · 09/10 14:20:00"))
    }

    @Test("sem pasta do app, diz onde procurou; argumento errado mostra a ajuda")
    func erros() {
        let raiz = pastaTemporaria()
        let semPasta = rodar(["resumo", "Exemplo"], contexto(raiz: raiz))
        #expect(semPasta.codigo == 1)
        #expect(semPasta.saida.contains("Nenhuma pasta da CaixaPreta com usos do Exemplo"))
        let opcaoErrada = rodar(["resumo", "Exemplo", "--dia", "2"], contexto(raiz: raiz))
        #expect(opcaoErrada.codigo == 2)
        #expect(opcaoErrada.saida.contains("Uso:"))
        #expect(rodar([], contexto(raiz: raiz)).codigo == 2)
        #expect(rodar(["simbolo", "AAAA", "x"], contexto(raiz: raiz)).codigo == 2)
    }

    @Test("simbolo traduz um endereço com o dSYM da pasta")
    func simbolo() {
        let resultado = rodar(
            ["simbolo", "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", "0x10", "--simbolos", dsymDeExemplo().path],
            contexto(raiz: pastaTemporaria())
        )
        #expect(resultado.codigo == 0)
        #expect(resultado.saida == "SessaoDeExemplo.verificar() (in Exemplo) (SessaoDeExemplo.swift:147)\n")
    }
}
