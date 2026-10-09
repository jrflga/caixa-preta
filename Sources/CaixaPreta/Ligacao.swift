#if os(iOS)
import MetricKit
import UIKit

/// Liga a caixa ao ciclo de vida do app e ao MetricKit. Sem teste de
/// unidade: é conferida compilando para iOS, no passeio do app e no aparelho.
final class Ligacao: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    /// O MetricKit não segura quem assina: a ligação fica guardada aqui.
    private static let atual = Guardado<Ligacao?>(nil)

    private let caixa: Caixa
    private var observadores: [any NSObjectProtocol] = []

    static func ligar(_ caixa: Caixa) {
        let ligacao = Ligacao(caixa: caixa)
        ligacao.comecar()
        atual.trocar { _ in ligacao }
    }

    private init(caixa: Caixa) {
        self.caixa = caixa
        super.init()
    }

    private func comecar() {
        let centro = NotificationCenter.default
        let caixa = caixa
        observadores = [
            centro.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                caixa.mudouDeEstado("frente")
            },
            centro.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    // A cópia para o iCloud termina mesmo que o iOS suspenda o app.
                    let tarefa = TarefaDeFundo { caixa.pararCopia() }
                    caixa.mudouDeEstado("fundo") {
                        Task { @MainActor in tarefa.terminar() }
                    }
                }
            },
            centro.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { _ in
                caixa.avisoDeMemoria()
            },
        ]
        let gerente = MXMetricManager.shared
        gerente.add(self)
        // Os relatórios que chegaram com o app fechado.
        for relatorio in gerente.pastDiagnosticPayloads {
            caixa.receberDiagnostico(relatorio.jsonRepresentation())
        }
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for relatorio in payloads { caixa.receberMetricas(relatorio.jsonRepresentation()) }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for relatorio in payloads { caixa.receberDiagnostico(relatorio.jsonRepresentation()) }
    }
}

/// Uma tarefa de fundo curta: pede ao iOS uns segundos para a cópia terminar.
@MainActor
final class TarefaDeFundo {
    private var id = UIBackgroundTaskIdentifier.invalid

    /// `aoExpirar` roda quando o iOS avisa que o tempo acabou, antes de a
    /// tarefa terminar.
    init(aoExpirar: @escaping @MainActor @Sendable () -> Void) {
        id = UIApplication.shared.beginBackgroundTask(withName: "CaixaPreta") { [weak self] in
            aoExpirar()
            self?.terminar()
        }
    }

    func terminar() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}
#endif
