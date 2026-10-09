@_exported import CaixaPretaFormato
import Foundation

/// A caixa-preta do app: anota o que acontece, no aparelho e no iCloud, para
/// entender depois por que o app fechou, travou ou deu problema.
public enum CaixaPreta {
    static let ligada = Guardado<Caixa?>(nil)

    /// Anota um evento. Não bloqueia; pode ser chamada de qualquer thread.
    /// O filtro de privacidade recusa o que não for código técnico, e no
    /// lugar entra `caixa.recusado`. Sem `ligar`, só a captura dos testes vê.
    public static func anotar(_ nome: String, _ campos: [String: Valor] = [:]) {
        let evento = ligada.atual?.anotar(nome, campos) ?? Caixa.filtrar(nome, campos, hora: Date(), uso: "")
        Captura.atual?.receber(evento)
    }

    /// Os últimos 3 dias num arquivo só, para um botão "Enviar diagnóstico"
    /// (`ShareLink`). Serve para quem usa o app com outra conta do iCloud.
    /// `nil` se a caixa não foi ligada.
    public static func arquivoParaEnviar() async -> URL? {
        await ligada.atual?.arquivoParaEnviar()
    }

    /// Roda `corpo` e devolve o que ele anotou, já passado pelo filtro. Só vê
    /// o que roda nesta tarefa e nas filhas: testes em paralelo não se
    /// misturam.
    public static func capturando(
        isolation: isolated (any Actor)? = #isolation,
        _ corpo: () async throws -> Void
    ) async rethrows -> [Evento] {
        let captura = Captura()
        try await Captura.$atual.withValue(captura) { try await corpo() }
        return captura.eventos
    }
}

/// O que `capturando` junta.
final class Captura: @unchecked Sendable {
    @TaskLocal static var atual: Captura?

    private let trava = NSLock()
    private var lista: [Evento] = []

    func receber(_ evento: Evento) {
        trava.withLock { lista.append(evento) }
    }

    var eventos: [Evento] {
        trava.withLock { lista }
    }
}

/// Um valor com trava, para o estado global da fachada.
final class Guardado<Conteudo>: @unchecked Sendable {
    private let trava = NSLock()
    private var conteudo: Conteudo

    init(_ conteudo: Conteudo) {
        self.conteudo = conteudo
    }

    var atual: Conteudo {
        trava.withLock { conteudo }
    }

    func trocar(_ mudar: (Conteudo) -> Conteudo) {
        trava.withLock { conteudo = mudar(conteudo) }
    }
}
