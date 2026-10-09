import CaixaPretaFormato
import Foundation

/// O que uma pasta de aparelho, ou um arquivo enviado, guarda.
public struct Registros {
    public var eventos: [Evento] = []
    /// O JSON cru de cada relatório do MetricKit, pelo nome sem `.json`.
    public var relatorios: [String: Data] = [:]

    public init() {}
}

public enum Leitura {
    /// `dias`: os nomes dos dias a ler ("2026-10-09"); `nil` lê todos.
    public static func ler(pasta: URL, dias: Set<String>? = nil) -> Registros {
        var registros = Registros()
        var lidos: [Evento] = []
        for nome in ((try? FileManager.default.contentsOfDirectory(atPath: pasta.path)) ?? []).sorted()
        where nome.wholeMatch(of: /\d{4}-\d{2}-\d{2}\.jsonl/) != nil && (dias?.contains(String(nome.prefix(10))) ?? true) {
            lidos += eventos(de: (try? Data(contentsOf: pasta.appending(path: nome))) ?? Data())
        }
        registros.eventos = emOrdem(lidos)
        let pastaDosRelatorios = pasta.appending(path: "diagnosticos", directoryHint: .isDirectory)
        for nome in (try? FileManager.default.contentsOfDirectory(atPath: pastaDosRelatorios.path)) ?? []
        where nome.hasSuffix(".json") && !nome.hasPrefix(".") {
            registros.relatorios[String(nome.dropLast(5))] = try? Data(contentsOf: pastaDosRelatorios.appending(path: nome))
        }
        return registros
    }

    /// O arquivo do botão "Enviar diagnóstico": linhas de evento e linhas
    /// `{"diagnostico": nome, "json": relatório}`.
    public static func ler(arquivoEnviado: URL) -> Registros {
        var registros = Registros()
        var lidos: [Evento] = []
        for linha in ((try? Data(contentsOf: arquivoEnviado)) ?? Data()).split(separator: 0x0A) {
            if let evento = Linha.decodificar(Data(linha)) {
                lidos.append(evento)
                continue
            }
            guard let objeto = (try? JSONSerialization.jsonObject(with: Data(linha))) as? [String: Any],
                  let nome = objeto["diagnostico"] as? String, let json = objeto["json"],
                  let dados = try? JSONSerialization.data(withJSONObject: json)
            else { continue }
            registros.relatorios[nome] = dados
        }
        registros.eventos = emOrdem(lidos)
        return registros
    }

    static func eventos(de dados: Data) -> [Evento] {
        dados.split(separator: 0x0A).compactMap { Linha.decodificar(Data($0)) }
    }

    /// Pela hora; na mesma hora, na ordem em que foram gravados.
    static func emOrdem(_ eventos: [Evento]) -> [Evento] {
        eventos.enumerated()
            .sorted { ($0.element.hora, $0.offset) < ($1.element.hora, $1.offset) }
            .map(\.element)
    }
}
