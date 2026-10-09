/// O que o app pode anotar: só códigos técnicos. Telefone, CPF, nome, frase e
/// código de entrar ("ABCD-1234") não passam.
public enum Filtro {
    public static let maximoDeCampos = 12

    /// O que foi recusado: o evento (ou `invalido`, se o nome não passa) e o
    /// campo (`nome`, `demais`, `invalido` ou o nome do campo). Nunca o valor.
    public struct Recusa: Equatable, Sendable {
        public let evento: String
        public let campo: String

        public init(evento: String, campo: String) {
            self.evento = evento
            self.campo = campo
        }
    }

    /// Começa com letra minúscula; depois letras minúsculas, algarismos, `_`,
    /// `.` e `-`; até 40.
    public static func aceita(_ texto: String) -> Bool {
        texto.wholeMatch(of: /[a-z][a-z0-9_.\-]{0,39}/) != nil
    }

    /// Número finito e menor que 1 bilhão: telefone e CPF não cabem.
    public static func aceita(_ valor: Valor) -> Bool {
        switch valor {
        case .texto(let texto): aceita(texto)
        case .inteiro(let numero): numero.magnitude < 1_000_000_000
        case .numero(let numero): numero.isFinite && numero.magnitude < 1_000_000_000
        case .booleano: true
        }
    }

    /// `nil` quando o evento passa inteiro.
    public static func conferir(_ nome: String, _ campos: [String: Valor]) -> Recusa? {
        guard aceita(nome) else { return Recusa(evento: "invalido", campo: "nome") }
        guard campos.count <= maximoDeCampos else { return Recusa(evento: nome, campo: "demais") }
        for chave in campos.keys.sorted() {
            guard aceita(chave) else { return Recusa(evento: nome, campo: "invalido") }
            guard let valor = campos[chave], aceita(valor) else { return Recusa(evento: nome, campo: chave) }
        }
        return nil
    }
}
