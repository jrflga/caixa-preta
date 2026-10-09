import CaixaPretaFormato
import Foundation

/// O texto do comando `resumo`: cada uso do app, como terminou, a memória,
/// os problemas, as falhas com a pilha e os últimos passos.
public enum Resumo {
    public static func texto(titulo: String, registros: Registros, simbolizador: Simbolizador?, fuso: TimeZone = .current) -> String {
        let formato = Formato(fuso: fuso)
        let usos = Usos.montar(registros.eventos)
        var linhas = [titulo]
        if usos.isEmpty { linhas += ["", "Nenhum uso no período."] }
        for uso in usos {
            linhas.append("")
            linhas += bloco(uso, registros: registros, simbolizador: simbolizador, formato: formato)
        }
        if let fechamentos = registros.eventos.last(where: { $0.nome == "ios.fechamentos" }) {
            linhas += ["", textoDosFechamentos(fechamentos.campos, formato: formato)]
        }
        return linhas.joined(separator: "\n") + "\n"
    }

    static func bloco(_ uso: Uso, registros: Registros, simbolizador: Simbolizador?, formato: Formato) -> [String] {
        let minutos = Int(uso.terminou.timeIntervalSince(uso.comecou) / 60)
        var linhas = [
            "Uso \(uso.id) · \(formato.diaEHora(uso.comecou)) → \(formato.hora(uso.terminou)) (\(minutos) min)"
                + " · versão \(uso.versao) (\(uso.build)) · iOS \(uso.ios)",
            "  Como terminou: \(descricao(uso.fim))",
        ]
        let avisos = uso.eventos.filter { $0.nome == "sessao.aviso_de_memoria" }.count
        if let pico = uso.picoMB {
            let doIOS = avisos == 0 ? "." : "; \(avisos) \(avisos == 1 ? "aviso" : "avisos") de memória do iOS."
            linhas.append("  Memória: pico \(pico) MB" + doIOS)
        }
        let contagem = Dictionary(grouping: uso.eventos.filter { !$0.nome.hasPrefix("sessao.") }, by: \.nome).mapValues(\.count)
        if !contagem.isEmpty {
            linhas.append("  Eventos: " + contagem.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: " · "))
        }
        let problemas = uso.eventos.filter(ehProblema)
        if !problemas.isEmpty {
            linhas.append("  Problemas:")
            linhas += problemas.suffix(10).map { "    " + formato.linha($0) }
        }
        for falha in uso.falhas {
            linhas.append("  Falha do iOS: " + descricaoDaFalha(falha.campos, formato: formato))
            guard let nome = falha.campos["relatorio"]?.texto, let json = registros.relatorios[nome],
                  let chave = falha.campos["chave"]?.texto, let indice = falha.campos["indice"]?.inteiro
            else { continue }
            for (posicao, quadro) in Pilha.quadros(json, chave: chave, indice: indice).enumerated() {
                let funcao = simbolizador?.nome(quadro) ?? "+0x" + String(quadro.deslocamento, radix: 16)
                linhas.append("    \(posicao)  \(quadro.binario)  \(funcao)")
            }
        }
        linhas.append("  Últimos passos:")
        linhas += uso.eventos.filter { $0.nome != "sessao.anterior" }.suffix(8).map { "    " + formato.linha($0) }
        return linhas
    }

    /// Regra para qualquer app: evento `*.problema` ou `*.erro`, campo `ok`
    /// falso, valor de texto que começa com `erro` ou `sem_`, e os avisos da
    /// própria caixa.
    static func ehProblema(_ evento: Evento) -> Bool {
        if evento.nome.hasSuffix(".problema") || evento.nome.hasSuffix(".erro") { return true }
        if ["caixa.recusado", "caixa.limite", "caixa.sem_icloud"].contains(evento.nome) { return true }
        if evento.campos["ok"] == .booleano(false) { return true }
        return evento.campos.values.contains { valor in
            guard let texto = valor.texto else { return false }
            return texto.hasPrefix("erro") || texto.hasPrefix("sem_")
        }
    }

    static func descricao(_ fim: Fim) -> String {
        switch fim {
        case .semAberturaSeguinte:
            "sem abertura seguinte (ainda aberto, ou fechado e não aberto de novo)."
        case .caiuNaFrente:
            "caiu com o app na tela (falha, travamento ou memória)."
        case .fechadoAntesDeAbrir:
            "fechado antes de a tela aparecer (falha na abertura)."
        case .fechadoLogoNoFundo(let segundos):
            "fechado logo depois de ir para o fundo; abriu de novo \(duracao(segundos)) depois do último sinal."
        case .fechadoNoFundo(let segundos):
            "fechado no fundo (normal no iOS); abriu de novo \(duracao(segundos)) depois do último sinal."
        }
    }

    /// 45 → "45 s"; 150 → "2 min"; 7200 → "2 h".
    static func duracao(_ segundos: Int) -> String {
        segundos < 60 ? "\(segundos) s" : segundos < 3600 ? "\(segundos / 60) min" : "\(segundos / 3600) h"
    }

    static let sinais = [
        4: "SIGILL: instrução inválida",
        5: "SIGTRAP: parada do Swift, como fatalError, opcional vazio ou índice fora",
        6: "SIGABRT: abortado",
        9: "SIGKILL: morto pelo sistema",
        10: "SIGBUS: acesso inválido à memória",
        11: "SIGSEGV: acesso inválido à memória",
    ]

    static let excecoes = [
        1: "EXC_BAD_ACCESS", 2: "EXC_BAD_INSTRUCTION", 5: "EXC_SOFTWARE", 6: "EXC_BREAKPOINT",
        10: "EXC_CRASH", 11: "EXC_RESOURCE", 12: "EXC_GUARD",
    ]

    static func descricaoDaFalha(_ campos: [String: Valor], formato: Formato) -> String {
        var partes = [campos["tipo"]?.texto ?? "?"]
        if let sinal = campos["sinal"]?.inteiro { partes.append("sinal \(sinal) (\(sinais[sinal] ?? "?"))") }
        if let excecao = campos["excecao"]?.inteiro { partes.append("exceção \(excecoes[excecao] ?? String(excecao))") }
        if let motivo = campos["motivo"]?.texto { partes.append("motivo: \(motivo)") }
        if let duracao = campos["duracao_ms"]?.inteiro { partes.append("\(duracao) ms") }
        if let de = data(campos["de"]), let ate = data(campos["ate"]) {
            partes.append("relatório de \(formato.hora(de)) a \(formato.hora(ate))")
        }
        if let versao = campos["versao"]?.texto { partes.append("versão \(versao) (\(campos["build"]?.texto ?? "?"))") }
        return partes.joined(separator: " · ")
    }

    static let motivos = [
        "normal": "normal", "memoria_limite": "memória (limite)", "pressao_de_memoria": "pressão de memória",
        "vigia": "vigia do sistema", "arquivo_travado": "arquivo travado", "acesso_invalido": "acesso inválido",
        "instrucao_invalida": "instrução inválida", "anormal": "anormal", "cpu_limite": "CPU (limite)",
        "tarefa_de_fundo": "tarefa de fundo estourou",
    ]

    static func textoDosFechamentos(_ campos: [String: Valor], formato: Formato) -> String {
        var partes: [String] = []
        for (prefixo, lugar) in [("frente_", "na frente"), ("fundo_", "no fundo")] {
            let contagens = campos.filter { $0.key.hasPrefix(prefixo) }
                .sorted { $0.key < $1.key }
                .map { "\(motivos[String($0.key.dropFirst(prefixo.count))] ?? $0.key) \($0.value.descricao)" }
            partes.append("\(lugar): " + (contagens.isEmpty ? "nenhum" : contagens.joined(separator: ", ")))
        }
        let janela = [data(campos["de"]), data(campos["ate"])].compactMap { $0 }.map(formato.diaEHora).joined(separator: " → ")
        return "Fechamentos contados pelo iOS" + (janela.isEmpty ? "" : " (\(janela))") + ": " + partes.joined(separator: "; ") + "."
    }

    static func data(_ valor: Valor?) -> Date? {
        valor?.texto.flatMap { try? Date($0, strategy: .iso8601) }
    }
}

/// Datas e linhas no fuso pedido.
struct Formato {
    let fuso: TimeZone

    func hora(_ data: Date) -> String { formatar(data, "HH:mm:ss") }

    func diaEHora(_ data: Date) -> String { formatar(data, "dd/MM HH:mm:ss") }

    /// "14:31:02 sessao.fundo memoria_mb=598"
    func linha(_ evento: Evento) -> String {
        ([hora(evento.hora), evento.nome] + campos(evento)).joined(separator: " ")
    }

    /// "09/10 14:31:02 7c1d9e02 sessao.fundo memoria_mb=598"
    func linhaCompleta(_ evento: Evento) -> String {
        ([diaEHora(evento.hora), evento.uso, evento.nome] + campos(evento)).joined(separator: " ")
    }

    private func campos(_ evento: Evento) -> [String] {
        evento.campos.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value.descricao)" }
    }

    private func formatar(_ data: Date, _ molde: String) -> String {
        let formatador = DateFormatter()
        formatador.locale = Locale(identifier: "pt_BR")
        formatador.timeZone = fuso
        formatador.dateFormat = molde
        return formatador.string(from: data)
    }
}
