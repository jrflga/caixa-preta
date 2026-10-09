import CaixaPretaFormato
import Testing

@Suite("Filtro de privacidade")
struct FiltroTests {
    @Test("códigos técnicos passam")
    func codigosPassam() {
        for texto in ["conectado", "pagina.situacao", "erro_na_pagina", "a1-b2", "radar", String(repeating: "a", count: 40)] {
            #expect(Filtro.aceita(texto), "\(texto)")
        }
    }

    @Test("telefone, CPF, código de entrar, nome e frase não passam")
    func dadosNaoPassam() {
        for texto in ["(21) 99999-0000", "21999990000", "123.456.789-00", "ABCD-1234", "Cliente Teste",
                      "o cliente pediu desconto", "joão", "", String(repeating: "a", count: 41)] {
            #expect(!Filtro.aceita(texto), "\(texto)")
        }
    }

    @Test("número grande ou infinito não passa")
    func numeros() {
        #expect(Filtro.aceita(.inteiro(830)))
        #expect(Filtro.aceita(.inteiro(-5)))
        #expect(Filtro.aceita(.numero(1.5)))
        #expect(Filtro.aceita(.booleano(true)))
        #expect(!Filtro.aceita(.inteiro(21_999_990_000)))
        #expect(!Filtro.aceita(.inteiro(12_345_678_900)))
        #expect(!Filtro.aceita(.inteiro(1_000_000_000)))
        #expect(!Filtro.aceita(.numero(.infinity)))
        #expect(!Filtro.aceita(.numero(.nan)))
    }

    @Test("a recusa diz o evento e o campo, nunca o valor")
    func recusas() {
        #expect(Filtro.conferir("pagina.situacao", ["site": "loja", "situacao": "conectado"]) == nil)
        #expect(Filtro.conferir("Cliente Teste", [:]) == Filtro.Recusa(evento: "invalido", campo: "nome"))
        #expect(Filtro.conferir("contato.novo", ["telefone": "(21) 99999-0000"]) == Filtro.Recusa(evento: "contato.novo", campo: "telefone"))
        #expect(Filtro.conferir("contato.novo", ["Telefone": "x"]) == Filtro.Recusa(evento: "contato.novo", campo: "invalido"))
        var muitos: [String: Valor] = [:]
        for numero in 0..<13 { muitos["c\(numero)"] = .inteiro(numero) }
        #expect(Filtro.conferir("teste.muitos", muitos) == Filtro.Recusa(evento: "teste.muitos", campo: "demais"))
    }
}
