import Foundation

/// Uma hora fixa a partir de um texto ISO 8601: `hora("2026-10-09T12:00:00-03:00")`.
public func hora(_ texto: String) -> Date {
    guard let data = try? Date(texto, strategy: .iso8601) else { fatalError("Hora inválida no teste: \(texto)") }
    return data
}

/// O calendário dos testes: o dia vira à meia-noite de Brasília.
public let calendarioDosTestes: Calendar = {
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    return calendario
}()

/// Um relógio que só anda quando o teste manda.
public final class Relogio: @unchecked Sendable {
    private let trava = NSLock()
    private var atual: Date

    public init(_ inicio: Date) { atual = inicio }

    public var agora: Date { trava.withLock { atual } }

    public func avancar(_ segundos: TimeInterval) { trava.withLock { atual += segundos } }
}

/// Um valor que o teste e a fila da caixa mexem ao mesmo tempo.
public final class Compartilhado<T: Sendable>: @unchecked Sendable {
    private let trava = NSLock()
    private var atual: T

    public init(_ inicial: T) { atual = inicial }

    public var valor: T {
        get { trava.withLock { atual } }
        set { trava.withLock { atual = newValue } }
    }
}

/// Uma pasta nova e vazia para cada teste.
public func pastaTemporaria() -> URL {
    let pasta = FileManager.default.temporaryDirectory
        .appending(path: "caixa-preta-testes/\(UUID().uuidString)", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
    return pasta
}
