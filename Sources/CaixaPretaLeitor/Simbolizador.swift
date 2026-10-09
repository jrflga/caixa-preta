import Foundation

/// Traduz endereço em nome de função com o dSYM da build. Acha o dSYM pelo
/// UUID do binário (`dwarfdump --uuid`) e traduz com o `atos`.
public struct Simbolizador {
    public typealias Rodar = (_ programa: String, _ argumentos: [String]) -> String

    /// Onde o segmento de texto de um app arm64 começa no dSYM.
    static let inicioDoTexto = 0x1_0000_0000

    private let dwarfPorUUID: [String: String]
    private let rodar: Rodar

    public init(pastas: [URL], rodar: @escaping Rodar = rodarDeVerdade) {
        self.rodar = rodar
        var mapa: [String: String] = [:]
        for pasta in pastas {
            let enumerador = FileManager.default.enumerator(at: pasta, includingPropertiesForKeys: nil)
            while let arquivo = enumerador?.nextObject() as? URL {
                guard arquivo.path.contains(".dSYM/Contents/Resources/DWARF/") else { continue }
                // "UUID: 1A2B… (arm64) /caminho"
                for linha in rodar("/usr/bin/xcrun", ["dwarfdump", "--uuid", arquivo.path]).split(separator: "\n") {
                    let partes = linha.split(separator: " ")
                    if partes.count >= 2, partes[0] == "UUID:" {
                        mapa[partes[1].uppercased()] = arquivo.path
                    }
                }
            }
        }
        dwarfPorUUID = mapa
    }

    /// O nome da função do quadro, ou `nil` sem o dSYM da build.
    public func nome(_ quadro: Quadro) -> String? {
        guard let dwarf = dwarfPorUUID[quadro.uuid.uppercased()] else { return nil }
        let endereco = "0x" + String(Self.inicioDoTexto + quadro.deslocamento, radix: 16)
        let saida = rodar("/usr/bin/xcrun", ["atos", "-o", dwarf, "-arch", "arm64", "-l", "0x100000000", endereco])
        let nome = saida.trimmingCharacters(in: .whitespacesAndNewlines)
        return nome.isEmpty || nome.hasPrefix("0x") ? nil : nome
    }
}

/// Roda um programa e devolve o que ele escreveu.
public func rodarDeVerdade(_ programa: String, _ argumentos: [String]) -> String {
    let processo = Process()
    processo.executableURL = URL(filePath: programa)
    processo.arguments = argumentos
    let saida = Pipe()
    processo.standardOutput = saida
    processo.standardError = Pipe()
    guard (try? processo.run()) != nil else { return "" }
    let dados = saida.fileHandleForReading.readDataToEndOfFile()
    processo.waitUntilExit()
    return String(decoding: dados, as: UTF8.self)
}
