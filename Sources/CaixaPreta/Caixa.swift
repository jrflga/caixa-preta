import CaixaPretaFormato
import Foundation

/// Grava, numa fila só e em ordem, o que o app anota e o que o sistema
/// conta. Quem chama nunca espera: o app pode anotar de qualquer thread.
final class Caixa: @unchecked Sendable {
    /// O código deste uso do app: 8 letras e algarismos.
    let uso: String
    /// O código aleatório do aparelho, criado na primeira abertura. O nome do
    /// aparelho não entra.
    let aparelho: String
    let ambiente: Ambiente
    let diario: Diario
    private let marcador: Marcador
    private let espelho: Espelho?
    private let fila = DispatchQueue(label: "caixa-preta")
    // Daqui para baixo, só na fila.
    private var marca: MarcaDoUso
    private var pulso: DispatchSourceTimer?
    private var limiteAvisado: Set<String> = []
    private var semICloudAvisado = false

    init(pasta: URL, ambiente: Ambiente, espelho: Espelho? = nil, calendario: Calendar = .current, limiteDoDia: Int = 5_000_000) {
        self.ambiente = ambiente
        self.espelho = espelho
        diario = Diario(pasta: pasta, calendario: calendario, limiteDoDia: limiteDoDia)
        marcador = Marcador(arquivo: pasta.appending(path: "uso-atual.json"))
        uso = Self.codigoNovo()
        aparelho = Self.aparelho(em: pasta)
        let agora = ambiente.agora()
        marca = MarcaDoUso(uso: uso, comecou: agora, estado: "abrindo", atualizado: agora, memoriaMB: 0, picoMB: 0)
    }

    /// Começa o uso: conta como terminou o anterior, grava o marcador novo,
    /// apaga o que venceu e copia para o iCloud. `intervaloDoPulso` `nil`
    /// desliga o pulso (testes).
    func comecar(intervaloDoPulso: TimeInterval? = 15) {
        let agora = ambiente.agora()
        fila.async { [self] in
            let memoria = ambiente.memoriaEmMB()
            gravar("sessao.comecou", [
                "app": .texto(ambiente.app), "versao": .texto(ambiente.versao), "build": .texto(ambiente.build),
                "ios": .texto(ambiente.ios), "modelo": .texto(ambiente.modelo), "memoria_mb": .inteiro(memoria),
            ], hora: agora)
            if let anterior = marcador.ler(), anterior.uso != uso {
                gravar("sessao.anterior", [
                    "uso": .texto(anterior.uso),
                    "estado": .texto(anterior.estado),
                    "duracao_s": .inteiro(Int(anterior.atualizado.timeIntervalSince(anterior.comecou))),
                    "parada_ha_s": .inteiro(Int(agora.timeIntervalSince(anterior.atualizado))),
                    "memoria_mb": .inteiro(anterior.memoriaMB),
                    "pico_mb": .inteiro(anterior.picoMB),
                ], hora: agora)
            }
            medir(memoria, hora: agora)
            diario.limparAntigos(hoje: agora)
            let ontem = diario.calendario.date(byAdding: .day, value: -1, to: agora) ?? agora
            diario.marcarParaCopiar([ontem, agora])
            espelharNaFila(depois: nil)
            if let intervaloDoPulso { ligarPulso(intervaloDoPulso) }
        }
    }

    /// Filtra e grava o que o app anotou. Devolve o evento como vai para o
    /// arquivo: o recusado vira `caixa.recusado`.
    @discardableResult
    func anotar(_ nome: String, _ campos: [String: Valor] = [:]) -> Evento {
        let evento = Self.filtrar(nome, campos, hora: ambiente.agora(), uso: uso)
        fila.async { [self] in
            if diario.gravar(evento, doApp: true) == .acimaDoLimite,
               limiteAvisado.insert(Dia.nome(evento.hora, calendario: diario.calendario)).inserted {
                gravar("caixa.limite", [:], hora: evento.hora)
            }
        }
        return evento
    }

    /// O evento que o filtro deixa gravar: o próprio, ou `caixa.recusado`.
    static func filtrar(_ nome: String, _ campos: [String: Valor], hora: Date, uso: String) -> Evento {
        guard let recusa = Filtro.conferir(nome, campos) else {
            return Evento(hora: hora, uso: uso, nome: nome, campos: campos)
        }
        return Evento(
            hora: hora, uso: uso, nome: "caixa.recusado",
            campos: ["evento": .texto(recusa.evento), "campo": .texto(recusa.campo)]
        )
    }

    /// `frente` ou `fundo`. Repetir o estado atual não grava nada. Ao ir para
    /// o fundo, copia para o iCloud e chama `depois` no fim da cópia.
    func mudouDeEstado(_ estado: String, depois: (@Sendable () -> Void)? = nil) {
        let agora = ambiente.agora()
        fila.async { [self] in
            guard marca.estado != estado else {
                depois?()
                return
            }
            let memoria = ambiente.memoriaEmMB()
            marca.estado = estado
            gravar("sessao.\(estado)", ["memoria_mb": .inteiro(memoria)], hora: agora)
            medir(memoria, hora: agora)
            if estado == "fundo" {
                espelharNaFila(depois: depois)
            } else {
                depois?()
            }
        }
    }

    func avisoDeMemoria() {
        let agora = ambiente.agora()
        fila.async { [self] in
            let memoria = ambiente.memoriaEmMB()
            gravar("sessao.aviso_de_memoria", ["memoria_mb": .inteiro(memoria)], hora: agora)
            medir(memoria, hora: agora)
        }
    }

    /// O sinal de vida: memória e hora no marcador, sem linha no arquivo.
    func pulsar() {
        let agora = ambiente.agora()
        fila.async { [self] in medir(ambiente.memoriaEmMB(), hora: agora) }
    }

    /// Um relatório de diagnóstico do MetricKit (`jsonRepresentation()`):
    /// guarda o JSON cru e anota uma `ios.falha` por diagnóstico. O mesmo
    /// relatório de novo não grava nada.
    func receberDiagnostico(_ json: Data) {
        fila.async { [self] in
            let agora = ambiente.agora()
            let falhas = LeituraDoMetricKit.falhas(json)
            guard !falhas.isEmpty, let relatorio = diario.guardarRelatorio(json, tipo: "diagnostico", hoje: agora) else { return }
            for var campos in falhas {
                campos["relatorio"] = .texto(relatorio)
                gravar("ios.falha", campos, hora: agora)
            }
        }
    }

    /// O relatório diário do MetricKit: anota as contagens de fechamento.
    func receberMetricas(_ json: Data) {
        fila.async { [self] in
            let agora = ambiente.agora()
            guard let campos = LeituraDoMetricKit.fechamentos(json),
                  diario.guardarRelatorio(json, tipo: "metricas", hoje: agora) != nil
            else { return }
            gravar("ios.fechamentos", campos, hora: agora)
        }
    }

    /// O tempo da tarefa de fundo acabou: para a cópia para o iCloud.
    func pararCopia() {
        espelho?.cancelar()
    }

    /// Espera a fila e a cópia terminarem o que já receberam. Para os testes.
    func esperar() {
        fila.sync {}
        espelho?.esperar()
        fila.sync {}
    }

    /// Junta os últimos 3 dias e os relatórios deles num arquivo só, para
    /// mandar por AirDrop, Mail ou Mensagens.
    func arquivoParaEnviar() async -> URL? {
        await withCheckedContinuation { continuacao in
            fila.async { [self] in continuacao.resume(returning: montarArquivo()) }
        }
    }

    private func montarArquivo() -> URL? {
        let calendario = diario.calendario
        let agora = ambiente.agora()
        let dias = (0..<3).reversed()
            .compactMap { calendario.date(byAdding: .day, value: -$0, to: agora) }
            .map { Dia.nome($0, calendario: calendario) }
        guard let primeiro = dias.first, let ultimo = dias.last else { return nil }
        var dados = Data()
        for dia in dias {
            dados.append((try? Data(contentsOf: diario.arquivo(doDia: dia))) ?? Data())
        }
        let relatorios = ((try? FileManager.default.contentsOfDirectory(atPath: diario.pastaDosRelatorios.path)) ?? []).sorted()
        for nome in relatorios where nome.hasSuffix(".json") && nome.prefix(10) >= primeiro {
            guard let json = try? Data(contentsOf: diario.pastaDosRelatorios.appending(path: nome)),
                  let objeto = try? JSONSerialization.jsonObject(with: json),
                  let linha = try? JSONSerialization.data(withJSONObject: ["diagnostico": String(nome.dropLast(5)), "json": objeto])
            else { continue }
            dados.append(linha)
            dados.append(0x0A)
        }
        let destino = FileManager.default.temporaryDirectory
            .appending(path: "CaixaPreta-\(ambiente.app)-\(aparelho)-\(ambiente.modelo)-\(ultimo).jsonl")
        do {
            try dados.write(to: destino, options: .atomic)
        } catch {
            return nil
        }
        return destino
    }

    // MARK: - Na fila

    private func gravar(_ nome: String, _ campos: [String: Valor], hora: Date) {
        diario.gravar(Evento(hora: hora, uso: uso, nome: nome, campos: campos), doApp: false)
    }

    private func medir(_ memoria: Int, hora: Date) {
        marca.memoriaMB = memoria
        marca.picoMB = max(marca.picoMB, memoria)
        marca.atualizado = max(marca.atualizado, hora)
        marcador.gravar(marca)
    }

    /// Copia para o iCloud e chama `depois` no fim da cópia. Sem iCloud,
    /// anota `caixa.sem_icloud` uma vez por uso.
    private func espelharNaFila(depois: (@Sendable () -> Void)?) {
        guard let espelho else {
            depois?()
            return
        }
        let agora = ambiente.agora()
        espelho.copiar(
            dias: diario.tirarDiasParaCopiar(),
            relatorios: diario.pastaDosRelatorios,
            para: "\(aparelho)-\(ambiente.modelo)",
            apagarAntesDe: diario.primeiroDiaGuardado(hoje: agora)
        ) { [self] haICloud in
            if !haICloud {
                fila.async { [self] in
                    guard !semICloudAvisado else { return }
                    semICloudAvisado = true
                    gravar("caixa.sem_icloud", [:], hora: ambiente.agora())
                }
            }
            depois?()
        }
    }

    private func ligarPulso(_ intervalo: TimeInterval) {
        let relogio = DispatchSource.makeTimerSource(queue: fila)
        relogio.schedule(deadline: .now() + intervalo, repeating: intervalo, leeway: .seconds(2))
        relogio.setEventHandler { [weak self] in
            guard let self else { return }
            medir(ambiente.memoriaEmMB(), hora: ambiente.agora())
        }
        relogio.resume()
        pulso = relogio
    }

    private static func codigoNovo() -> String {
        String(UUID().uuidString.prefix(8)).lowercased()
    }

    private static func aparelho(em pasta: URL) -> String {
        let arquivo = pasta.appending(path: "aparelho.txt")
        if let salvo = try? String(contentsOf: arquivo, encoding: .utf8), salvo.wholeMatch(of: /[0-9a-f]{8}/) != nil {
            return salvo
        }
        let novo = codigoNovo()
        try? Data(novo.utf8).write(to: arquivo, options: Diario.opcoesDeEscrita)
        return novo
    }
}
