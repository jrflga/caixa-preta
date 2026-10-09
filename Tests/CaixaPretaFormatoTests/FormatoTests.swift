import ApoioDosTestes
import CaixaPretaFormato
import Foundation
import Testing

@Suite("Formato do arquivo")
struct FormatoTests {
    @Test("a linha vai e volta com os quatro tipos de valor")
    func idaEVolta() {
        let evento = Evento(
            hora: hora("2026-10-09T12:00:00-03:00").addingTimeInterval(0.25),
            uso: "7c1d9e02",
            nome: "busca.leitura",
            campos: ["acao": "radar", "ok": true, "ms": 830, "fator": 1.5]
        )
        let linha = Linha.codificar(evento)
        #expect(linha.last == 0x0A)
        let texto = String(decoding: linha, as: UTF8.self)
        #expect(texto.hasPrefix(#"{"d":{"acao":"radar","fator":1.5,"ms":830,"ok":true},"e":"busca.leitura","t":"#))
        #expect(texto.hasSuffix(#","u":"7c1d9e02"}"# + "\n"))
        #expect(Linha.decodificar(linha) == evento)
        #expect(Linha.decodificar(linha.dropLast()) == evento)
    }

    @Test("linha quebrada não vira evento")
    func linhaQuebrada() {
        #expect(Linha.decodificar(Data(#"{"t":"ontem","u":"x","e":"a","d":{}}"#.utf8)) == nil)
        #expect(Linha.decodificar(Data(#"{"t":"#.utf8)) == nil)
        #expect(Linha.decodificar(Data()) == nil)
    }

    @Test("um arquivo por dia, pelo calendário do aparelho")
    func nomeDoDia() {
        #expect(Dia.nome(hora("2026-10-09T23:59:59-03:00"), calendario: calendarioDosTestes) == "2026-10-09")
        #expect(Dia.nome(hora("2026-10-10T00:00:01-03:00"), calendario: calendarioDosTestes) == "2026-10-10")
        #expect(Dia.data(doNome: "2026-10-09.jsonl", calendario: calendarioDosTestes) == hora("2026-10-09T00:00:00-03:00"))
        #expect(Dia.data(doNome: "2026-10-09-diagnostico-ab12.json", calendario: calendarioDosTestes) != nil)
        #expect(Dia.data(doNome: "uso-atual.json", calendario: calendarioDosTestes) == nil)
        #expect(Dia.data(doNome: ".2026-10-09.jsonl.icloud", calendario: calendarioDosTestes) == nil)
    }

    @Test("número com vírgula sem fração volta como inteiro")
    func numeroSemFracao() {
        let linha = Linha.codificar(Evento(hora: hora("2026-10-09T12:00:00-03:00"), uso: "a", nome: "b", campos: ["x": 2.0]))
        #expect(Linha.decodificar(linha)?.campos["x"] == .inteiro(2))
    }

    @Test("descrição para ler no terminal")
    func descricao() {
        #expect(Valor.texto("conectado").descricao == "conectado")
        #expect(Valor.inteiro(830).descricao == "830")
        #expect(Valor.numero(1.5).descricao == "1,5")
        #expect(Valor.booleano(false).descricao == "não")
    }
}
