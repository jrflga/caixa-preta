import Foundation

/// Copia os arquivos da caixa para a pasta do app no iCloud Drive, numa fila
/// própria: o iCloud pode demorar, e a gravação não espera por ele.
final class Espelho: @unchecked Sendable {
    private let fila = DispatchQueue(label: "caixa-preta.espelho")
    private let acharRaiz: @Sendable () -> URL?
    /// Cada `cancelar` abre uma geração nova: a cópia pedida antes dela para
    /// no próximo arquivo; a pedida depois roda inteira.
    private let geracao = Guardado(0)
    /// Só na fila. Achada uma vez; sem iCloud, tenta de novo na próxima cópia.
    private var raiz: URL?

    /// `acharRaiz` devolve a raiz do container do iCloud, ou `nil` sem
    /// iCloud. Roda nesta fila: a primeira chamada pode demorar.
    init(acharRaiz: @escaping @Sendable () -> URL?) {
        self.acharRaiz = acharRaiz
    }

    /// Copia os `dias` (substituindo) e os relatórios que faltam para
    /// `Documents/CaixaPreta/<subpasta>/`, e apaga lá o que é anterior a
    /// `apagarAntesDe`. Chama `depois(false)` quando não há iCloud.
    func copiar(
        dias: [URL],
        relatorios: URL,
        para subpasta: String,
        apagarAntesDe dia: String,
        depois: @escaping @Sendable (Bool) -> Void
    ) {
        let pedido = geracao.atual
        fila.async { [self] in
            let valendo = { self.geracao.atual == pedido }
            if raiz == nil { raiz = acharRaiz() }
            guard let raiz else {
                depois(false)
                return
            }
            let destino = raiz.appending(path: "Documents/CaixaPreta/\(subpasta)", directoryHint: .isDirectory)
            let destinoDosRelatorios = destino.appending(path: "diagnosticos", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: destinoDosRelatorios, withIntermediateDirectories: true)
            for arquivo in dias where valendo() {
                substituir(destino.appending(path: arquivo.lastPathComponent), por: arquivo)
            }
            for nome in (try? FileManager.default.contentsOfDirectory(atPath: relatorios.path)) ?? []
            where valendo() && !FileManager.default.fileExists(atPath: destinoDosRelatorios.appending(path: nome).path) {
                substituir(destinoDosRelatorios.appending(path: nome), por: relatorios.appending(path: nome))
            }
            Diario.apagar(em: [destino, destinoDosRelatorios], antesDe: dia) { arquivo in
                guard valendo() else { return }
                NSFileCoordinator().coordinate(writingItemAt: arquivo, options: .forDeleting, error: nil) { url in
                    try? FileManager.default.removeItem(at: url)
                }
            }
            depois(true)
        }
    }

    /// O iOS pediu o fim da tarefa de fundo: a cópia em andamento para antes
    /// do próximo arquivo. Seguir escrevendo com o app suspenso pode fazer o
    /// iOS fechar o app (arquivo travado).
    func cancelar() {
        geracao.trocar { $0 + 1 }
    }

    /// Espera a cópia em andamento. Para os testes e para a caixa.
    func esperar() {
        fila.sync {}
    }

    private func substituir(_ destino: URL, por origem: URL) {
        guard let dados = try? Data(contentsOf: origem) else { return }
        NSFileCoordinator().coordinate(writingItemAt: destino, options: .forReplacing, error: nil) { url in
            try? dados.write(to: url, options: .atomic)
        }
    }
}
