import Foundation

/// O valor de um campo: texto, inteiro, número com vírgula ou sim/não.
/// Aceita literais: `["site": "loja", "ok": true, "ms": 830]`.
public enum Valor: Sendable, Equatable {
    case texto(String)
    case inteiro(Int)
    case numero(Double)
    case booleano(Bool)

    public var texto: String? {
        if case .texto(let valor) = self { valor } else { nil }
    }

    public var inteiro: Int? {
        if case .inteiro(let valor) = self { valor } else { nil }
    }

    public var numero: Double? {
        switch self {
        case .numero(let valor): valor
        case .inteiro(let valor): Double(valor)
        case .texto, .booleano: nil
        }
    }

    public var booleano: Bool? {
        if case .booleano(let valor) = self { valor } else { nil }
    }

    /// Como aparece no terminal: `conectado`, `830`, `1,5`, `sim`.
    public var descricao: String {
        switch self {
        case .texto(let valor): valor
        case .inteiro(let valor): String(valor)
        case .numero(let valor): valor.formatted(.number.locale(Locale(identifier: "pt_BR")))
        case .booleano(let valor): valor ? "sim" : "não"
        }
    }
}

extension Valor: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByBooleanLiteral {
    public init(stringLiteral valor: String) { self = .texto(valor) }
    public init(integerLiteral valor: Int) { self = .inteiro(valor) }
    public init(floatLiteral valor: Double) { self = .numero(valor) }
    public init(booleanLiteral valor: Bool) { self = .booleano(valor) }
}

/// No JSON, o valor vai cru. Na volta, `2.0` vira inteiro: o JSON não
/// distingue os dois.
extension Valor: Codable {
    public init(from decoder: any Decoder) throws {
        let conteudo = try decoder.singleValueContainer()
        if let valor = try? conteudo.decode(Bool.self) {
            self = .booleano(valor)
        } else if let valor = try? conteudo.decode(Int.self) {
            self = .inteiro(valor)
        } else if let valor = try? conteudo.decode(Double.self) {
            self = .numero(valor)
        } else {
            self = .texto(try conteudo.decode(String.self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var conteudo = encoder.singleValueContainer()
        switch self {
        case .texto(let valor): try conteudo.encode(valor)
        case .inteiro(let valor): try conteudo.encode(valor)
        case .numero(let valor): try conteudo.encode(valor)
        case .booleano(let valor): try conteudo.encode(valor)
        }
    }
}
