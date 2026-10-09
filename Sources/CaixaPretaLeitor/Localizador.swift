import CaixaPretaFormato
import Foundation

/// Acha as pastas da caixa de um app no iCloud Drive do Mac.
public enum Localizador {
    public static let raizPadrao = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Mobile Documents", directoryHint: .isDirectory)

    /// As pastas de aparelho (`<código>-<modelo>`) que têm usos do `app`, em
    /// todos os containers (`iCloud~…`). Antes de ler, baixa o que o iCloud
    /// ainda não trouxe para o Mac.
    public static func pastas(doApp app: String, raiz: URL = raizPadrao, baixar: (URL) -> Void = baixarComBrctl) -> [URL] {
        let gerente = FileManager.default
        var achadas: [URL] = []
        let containers = ((try? gerente.contentsOfDirectory(atPath: raiz.path)) ?? []).filter { $0.hasPrefix("iCloud~") }.sorted()
        for container in containers {
            let caixa = raiz.appending(path: "\(container)/Documents/CaixaPreta", directoryHint: .isDirectory)
            for aparelho in ((try? gerente.contentsOfDirectory(atPath: caixa.path)) ?? []).sorted() where !aparelho.hasPrefix(".") {
                let pasta = caixa.appending(path: aparelho, directoryHint: .isDirectory)
                baixarPendentes(em: pasta, baixar: baixar)
                let comecos = Leitura.ler(pasta: pasta).eventos.filter { $0.nome == "sessao.comecou" }
                if comecos.contains(where: { $0.campos["app"]?.texto == app }) {
                    achadas.append(pasta)
                }
            }
        }
        return achadas
    }

    /// `.2026-10-09.jsonl.icloud` → `2026-10-09.jsonl`: pede cada um e espera
    /// até 30 s.
    static func baixarPendentes(em pasta: URL, baixar: (URL) -> Void, prazo: TimeInterval = 30) {
        let faltando = [pasta, pasta.appending(path: "diagnosticos", directoryHint: .isDirectory)].flatMap { pendentes(em: $0) }
        guard !faltando.isEmpty else { return }
        faltando.forEach(baixar)
        let fim = Date().addingTimeInterval(prazo)
        while Date() < fim, faltando.contains(where: { !FileManager.default.fileExists(atPath: $0.path) }) {
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    static func pendentes(em pasta: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(atPath: pasta.path)) ?? [])
            .filter { $0.hasPrefix(".") && $0.hasSuffix(".icloud") }
            .map { pasta.appending(path: String($0.dropFirst().dropLast(".icloud".count))) }
    }
}

/// Pede ao iCloud Drive do Mac para baixar o arquivo.
public func baixarComBrctl(_ arquivo: URL) {
    let processo = Process()
    processo.executableURL = URL(filePath: "/usr/bin/brctl")
    processo.arguments = ["download", arquivo.path]
    guard (try? processo.run()) != nil else { return }
    processo.waitUntilExit()
}
