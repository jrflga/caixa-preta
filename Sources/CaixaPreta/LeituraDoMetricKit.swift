import CaixaPretaFormato
import Foundation

/// Lê os relatórios do MetricKit pelo JSON (`jsonRepresentation()`): é o que
/// fica guardado e o que os testes montam sem o iOS.
enum LeituraDoMetricKit {
    static let tipos = [
        ("crashDiagnostics", "falha"),
        ("hangDiagnostics", "travamento"),
        ("cpuExceptionDiagnostics", "cpu"),
        ("diskWriteExceptionDiagnostics", "disco"),
        ("appLaunchDiagnostics", "abertura"),
    ]

    static let motivos = [
        ("cumulativeNormalAppExitCount", "normal"),
        ("cumulativeMemoryResourceLimitExitCount", "memoria_limite"),
        ("cumulativeMemoryPressureExitCount", "pressao_de_memoria"),
        ("cumulativeAppWatchdogExitCount", "vigia"),
        ("cumulativeSuspendedWithLockedFileExitCount", "arquivo_travado"),
        ("cumulativeBadAccessExitCount", "acesso_invalido"),
        ("cumulativeIllegalInstructionExitCount", "instrucao_invalida"),
        ("cumulativeAbnormalExitCount", "anormal"),
        ("cumulativeCPUResourceLimitExitCount", "cpu_limite"),
        ("cumulativeBackgroundTaskAssertionTimeoutExitCount", "tarefa_de_fundo"),
    ]

    /// Um conjunto de campos por diagnóstico do relatório.
    static func falhas(_ json: Data) -> [[String: Valor]] {
        guard let raiz = objeto(json) else { return [] }
        let janela = janela(raiz)
        var falhas: [[String: Valor]] = []
        for (chave, tipo) in tipos {
            for (indice, item) in ((raiz[chave] as? [[String: Any]]) ?? []).enumerated() {
                let meta = item["diagnosticMetaData"] as? [String: Any] ?? [:]
                var campos = janela
                campos["tipo"] = .texto(tipo)
                campos["chave"] = .texto(chave)
                campos["indice"] = .inteiro(indice)
                if let sinal = meta["signal"] as? Int { campos["sinal"] = .inteiro(sinal) }
                if let excecao = meta["exceptionType"] as? Int { campos["excecao"] = .inteiro(excecao) }
                if let codigo = meta["exceptionCode"] as? Int { campos["codigo"] = .inteiro(codigo) }
                if let motivo = meta["terminationReason"] as? String { campos["motivo"] = .texto(String(motivo.prefix(160))) }
                if let duracao = (meta["hangDuration"] ?? meta["launchDuration"]) as? String, let ms = milissegundos(duracao) {
                    campos["duracao_ms"] = .inteiro(ms)
                }
                if let versao = meta["appVersion"] as? String { campos["versao"] = .texto(versao) }
                if let build = meta["appBuildVersion"] as? String { campos["build"] = .texto(build) }
                falhas.append(campos)
            }
        }
        return falhas
    }

    /// As contagens de fechamento maiores que zero, na frente e no fundo.
    /// `nil` se o relatório não traz fechamentos.
    static func fechamentos(_ json: Data) -> [String: Valor]? {
        guard let raiz = objeto(json), let saidas = raiz["applicationExitMetrics"] as? [String: Any] else { return nil }
        var campos = janela(raiz)
        for (lado, prefixo) in [("foregroundExitData", "frente"), ("backgroundExitData", "fundo")] {
            let dados = saidas[lado] as? [String: Any] ?? [:]
            for (chave, motivo) in motivos {
                if let contagem = dados[chave] as? Int, contagem > 0 {
                    campos["\(prefixo)_\(motivo)"] = .inteiro(contagem)
                }
            }
        }
        return campos
    }

    /// "2.5 sec", "830 ms", "1.5 min" → milissegundos.
    static func milissegundos(_ texto: String) -> Int? {
        let partes = texto.split(separator: " ")
        guard let numero = partes.first.flatMap({ Double($0) }) else { return nil }
        let unidade = partes.count > 1 ? partes[1].lowercased() : "sec"
        let fator: Double = unidade.hasPrefix("ms") ? 1 : unidade.hasPrefix("min") ? 60_000 : 1000
        return Int(numero * fator)
    }

    /// O começo e o fim do relatório, em ISO 8601 (UTC).
    private static func janela(_ raiz: [String: Any]) -> [String: Valor] {
        var campos: [String: Valor] = [:]
        if let de = data(raiz["timeStampBegin"]) { campos["de"] = .texto(de.formatted(.iso8601)) }
        if let ate = data(raiz["timeStampEnd"]) { campos["ate"] = .texto(ate.formatted(.iso8601)) }
        return campos
    }

    /// "2026-10-09 17:31:00 +0000", como o MetricKit escreve.
    private static func data(_ valor: Any?) -> Date? {
        guard let texto = valor as? String else { return nil }
        let leitor = DateFormatter()
        leitor.locale = Locale(identifier: "en_US_POSIX")
        leitor.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return leitor.date(from: texto)
    }

    private static func objeto(_ json: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: json)) as? [String: Any]
    }
}
