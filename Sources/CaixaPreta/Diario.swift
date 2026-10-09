import CaixaPretaFormato
import CryptoKit
import Foundation

/// Os arquivos da caixa no aparelho: um `.jsonl` por dia e os relatórios do
/// MetricKit em `diagnosticos/`. Só a fila da caixa mexe nele.
final class Diario {
    static let diasGuardados = 14

    enum Resultado: Equatable { case gravado, acimaDoLimite }

    let pasta: URL
    let pastaDosRelatorios: URL
    let calendario: Calendar
    private let limiteDoDia: Int
    /// Bytes de anotações do app por dia. Começa do tamanho do arquivo.
    private var bytesDoApp: [String: Int] = [:]
    /// Dias com linhas novas desde a última cópia para o iCloud.
    private var diasMexidos: Set<String> = []

    init(pasta: URL, calendario: Calendar = .current, limiteDoDia: Int = 5_000_000) {
        self.pasta = pasta
        pastaDosRelatorios = pasta.appending(path: "diagnosticos", directoryHint: .isDirectory)
        self.calendario = calendario
        self.limiteDoDia = limiteDoDia
        for criar in [pasta, pastaDosRelatorios] {
            try? FileManager.default.createDirectory(at: criar, withIntermediateDirectories: true, attributes: Self.protecao())
        }
    }

    func arquivo(doDia dia: String) -> URL {
        pasta.appending(path: "\(dia).jsonl")
    }

    /// Grava uma linha no arquivo do dia do evento. `doApp` conta para o
    /// limite do dia; os eventos da própria caixa não contam.
    @discardableResult
    func gravar(_ evento: Evento, doApp: Bool) -> Resultado {
        let linha = Linha.codificar(evento)
        guard !linha.isEmpty else { return .gravado }
        let dia = Dia.nome(evento.hora, calendario: calendario)
        if doApp {
            let usados = bytesDoApp[dia] ?? tamanho(arquivo(doDia: dia))
            guard usados + linha.count <= limiteDoDia else { return .acimaDoLimite }
            bytesDoApp[dia] = usados + linha.count
        }
        acrescentar(linha, em: arquivo(doDia: dia))
        diasMexidos.insert(dia)
        return .gravado
    }

    /// Marca dias para a próxima cópia. Na abertura: hoje e ontem, para levar
    /// o fim do uso anterior, que pode não ter sido copiado.
    func marcarParaCopiar(_ datas: [Date]) {
        for data in datas { diasMexidos.insert(Dia.nome(data, calendario: calendario)) }
    }

    /// Os arquivos dos dias com linhas novas desde a última vez; zera a lista.
    func tirarDiasParaCopiar() -> [URL] {
        defer { diasMexidos.removeAll() }
        return diasMexidos.sorted().map { arquivo(doDia: $0) }
    }

    /// Guarda o JSON cru de um relatório do MetricKit. Devolve o nome do
    /// arquivo sem `.json`, ou `nil` se esse relatório já estava guardado.
    func guardarRelatorio(_ json: Data, tipo: String, hoje: Date) -> String? {
        let marca = SHA256.hash(data: json).prefix(8).map { String(format: "%02x", $0) }.joined()
        let existentes = (try? FileManager.default.contentsOfDirectory(atPath: pastaDosRelatorios.path)) ?? []
        guard !existentes.contains(where: { $0.hasSuffix("-\(marca).json") }) else { return nil }
        let nome = "\(Dia.nome(hoje, calendario: calendario))-\(tipo)-\(marca)"
        try? json.write(to: pastaDosRelatorios.appending(path: "\(nome).json"), options: Self.opcoesDeEscrita)
        return nome
    }

    /// O dia mais antigo que fica: hoje menos 13.
    func primeiroDiaGuardado(hoje: Date) -> String {
        let inicio = calendario.startOfDay(for: hoje)
        let primeiro = calendario.date(byAdding: .day, value: -(Self.diasGuardados - 1), to: inicio) ?? inicio
        return Dia.nome(primeiro, calendario: calendario)
    }

    func limparAntigos(hoje: Date) {
        Self.apagar(em: [pasta, pastaDosRelatorios], antesDe: primeiroDiaGuardado(hoje: hoje))
    }

    /// Apaga, nas pastas, os arquivos com data no nome anterior a `dia`.
    /// Outros arquivos ficam.
    static func apagar(em pastas: [URL], antesDe dia: String, apagar: (URL) -> Void = { try? FileManager.default.removeItem(at: $0) }) {
        for pasta in pastas {
            for nome in (try? FileManager.default.contentsOfDirectory(atPath: pasta.path)) ?? []
            where Dia.data(doNome: nome) != nil && nome.prefix(10) < dia {
                apagar(pasta.appending(path: nome))
            }
        }
    }

    /// O app grava no fundo e com o aparelho bloqueado: proteção até o
    /// primeiro desbloqueio, e não a completa.
    static let opcoesDeEscrita: Data.WritingOptions = {
        #if os(iOS)
        return [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        #else
        return [.atomic]
        #endif
    }()

    static func protecao() -> [FileAttributeKey: Any] {
        #if os(iOS)
        return [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        #else
        return [:]
        #endif
    }

    private func tamanho(_ arquivo: URL) -> Int {
        guard let leitor = try? FileHandle(forReadingFrom: arquivo) else { return 0 }
        defer { try? leitor.close() }
        return Int((try? leitor.seekToEnd()) ?? 0)
    }

    /// Abre, acrescenta e fecha a cada linha: nada fica aberto quando o iOS
    /// suspende o app.
    private func acrescentar(_ linha: Data, em arquivo: URL) {
        if !FileManager.default.fileExists(atPath: arquivo.path) {
            FileManager.default.createFile(atPath: arquivo.path, contents: nil, attributes: Self.protecao())
        }
        guard let escritor = try? FileHandle(forWritingTo: arquivo) else { return }
        defer { try? escritor.close() }
        _ = try? escritor.seekToEnd()
        try? escritor.write(contentsOf: linha)
    }
}
