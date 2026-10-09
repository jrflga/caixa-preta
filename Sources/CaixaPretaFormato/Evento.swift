import Foundation

/// Uma linha da caixa: quando, em que uso do app, o quê e os detalhes.
public struct Evento: Sendable, Equatable {
    public let hora: Date
    /// O código do uso do app (de uma abertura até o app fechar).
    public let uso: String
    public let nome: String
    public let campos: [String: Valor]

    public init(hora: Date, uso: String, nome: String, campos: [String: Valor] = [:]) {
        self.hora = hora
        self.uso = uso
        self.nome = nome
        self.campos = campos
    }
}

/// O formato do arquivo: uma linha JSON por evento, com chaves curtas
/// (`t` hora com fuso, `u` uso, `e` evento, `d` campos).
public enum Linha {
    private struct Bruta: Codable {
        let t: String
        let u: String
        let e: String
        let d: [String: Valor]
    }

    static let estiloDaHora = Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current)

    /// A linha com `\n` no fim; vazia se o evento não vira JSON.
    public static func codificar(_ evento: Evento) -> Data {
        let bruta = Bruta(t: evento.hora.formatted(estiloDaHora), u: evento.uso, e: evento.nome, d: evento.campos)
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard var dados = try? codificador.encode(bruta) else { return Data() }
        dados.append(0x0A)
        return dados
    }

    public static func decodificar(_ linha: Data) -> Evento? {
        guard let bruta = try? JSONDecoder().decode(Bruta.self, from: linha),
              let hora = try? Date(bruta.t, strategy: estiloDaHora)
        else { return nil }
        return Evento(hora: hora, uso: bruta.u, nome: bruta.e, campos: bruta.d)
    }
}

/// O nome do arquivo de cada dia, pelo calendário do aparelho: `2026-10-09`.
public enum Dia {
    public static func nome(_ data: Date, calendario: Calendar = .current) -> String {
        let partes = calendario.dateComponents([.year, .month, .day], from: data)
        return String(format: "%04ld-%02ld-%02ld", partes.year ?? 0, partes.month ?? 0, partes.day ?? 0)
    }

    /// A data do começo do nome (`2026-10-09.jsonl`, `2026-10-09-diagnostico-….json`),
    /// ou `nil` se o nome não começa com uma data.
    public static func data(doNome nome: String, calendario: Calendar = .current) -> Date? {
        let partes = nome.prefix(10).split(separator: "-", omittingEmptySubsequences: false)
        guard partes.count == 3, partes[0].count == 4, partes[1].count == 2, partes[2].count == 2,
              let ano = Int(partes[0]), let mes = Int(partes[1]), let dia = Int(partes[2])
        else { return nil }
        return calendario.date(from: DateComponents(year: ano, month: mes, day: dia))
    }
}
