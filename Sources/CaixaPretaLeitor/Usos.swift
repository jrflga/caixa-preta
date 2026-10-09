import CaixaPretaFormato
import Foundation

/// Como um uso do app terminou, visto da abertura seguinte.
public enum Fim: Equatable, Sendable {
    /// Ainda não houve abertura seguinte: o app está aberto, ou fechou e não
    /// abriu mais.
    case semAberturaSeguinte
    /// Com o app na tela: falha, travamento ou memória. O mais grave.
    case caiuNaFrente
    /// Antes de a tela aparecer: falha na abertura.
    case fechadoAntesDeAbrir
    /// No fundo, e a abertura seguinte veio em menos de 10 minutos.
    case fechadoLogoNoFundo(voltouDepoisDe: Int)
    /// No fundo, e a abertura seguinte veio depois. Normal no iOS.
    case fechadoNoFundo(voltouDepoisDe: Int)
}

/// Um uso do app: da abertura até o último sinal.
public struct Uso {
    public let id: String
    public let comecou: Date
    public let versao: String
    public let build: String
    public let ios: String
    public var eventos: [Evento] = []
    /// As `ios.falha` deste uso, mesmo as que chegaram no uso seguinte.
    public var falhas: [Evento] = []
    public var fim = Fim.semAberturaSeguinte
    /// O que a abertura seguinte contou do último sinal.
    public var memoriaNoFim: Int?
    public var picoNoFim: Int?
    public var duracaoNoFim: Int?
    /// Quando a abertura seguinte contou como este uso terminou.
    public var fimContadoEm: Date?

    /// A memória mais alta vista no uso, em MB. A `sessao.anterior` gravada
    /// neste uso traz a memória do uso de antes: não conta.
    public var picoMB: Int? {
        let medidas = eventos.filter { $0.nome != "sessao.anterior" }.compactMap { $0.campos["memoria_mb"]?.inteiro }
        return (medidas + [memoriaNoFim, picoNoFim].compactMap { $0 }).max()
    }

    /// O último sinal do uso, contando o que chegou depois dele: a abertura
    /// seguinte que contou como ele terminou e as falhas do iOS.
    public var ultimoSinal: Date {
        ([terminou] + [fimContadoEm].compactMap { $0 } + falhas.map(\.hora)).max() ?? terminou
    }

    /// Até quando há sinal do uso.
    public var terminou: Date {
        max(eventos.last?.hora ?? comecou, comecou.addingTimeInterval(TimeInterval(duracaoNoFim ?? 0)))
    }
}

public enum Usos {
    /// "Logo depois de ir para o fundo": a abertura seguinte em menos de 10 min.
    public static let limiteDoLogo = 600

    public static func montar(_ eventos: [Evento]) -> [Uso] {
        var usos: [String: Uso] = [:]
        for evento in eventos where evento.nome == "sessao.comecou" {
            usos[evento.uso] = Uso(
                id: evento.uso,
                comecou: evento.hora,
                versao: evento.campos["versao"]?.texto ?? "?",
                build: evento.campos["build"]?.texto ?? "?",
                ios: evento.campos["ios"]?.texto ?? "?"
            )
        }
        for evento in eventos where evento.nome != "ios.falha" {
            usos[evento.uso]?.eventos.append(evento)
        }
        for evento in eventos where evento.nome == "sessao.anterior" {
            guard let id = evento.campos["uso"]?.texto, usos[id] != nil else { continue }
            usos[id]?.fim = fim(evento.campos)
            usos[id]?.memoriaNoFim = evento.campos["memoria_mb"]?.inteiro
            usos[id]?.picoNoFim = evento.campos["pico_mb"]?.inteiro
            usos[id]?.duracaoNoFim = evento.campos["duracao_s"]?.inteiro
            usos[id]?.fimContadoEm = evento.hora
        }
        let ordem = usos.values.sorted { $0.comecou < $1.comecou }.map(\.id)
        for falha in eventos where falha.nome == "ios.falha" {
            usos[destino(da: falha, ordem: ordem, usos: usos)]?.falhas.append(falha)
        }
        return ordem.compactMap { usos[$0] }
    }

    static func fim(_ campos: [String: Valor]) -> Fim {
        let parada = campos["parada_ha_s"]?.inteiro ?? 0
        switch campos["estado"]?.texto {
        case "frente": return .caiuNaFrente
        case "abrindo": return .fechadoAntesDeAbrir
        default: return parada < limiteDoLogo ? .fechadoLogoNoFundo(voltouDepoisDe: parada) : .fechadoNoFundo(voltouDepoisDe: parada)
        }
    }

    /// A falha chega na abertura seguinte: vai para o uso anterior ao que a
    /// recebeu, se ele começou antes do fim da janela do relatório.
    static func destino(da falha: Evento, ordem: [String], usos: [String: Uso]) -> String {
        let ate = falha.campos["ate"]?.texto.flatMap { try? Date($0, strategy: .iso8601) } ?? falha.hora
        guard let posicao = ordem.firstIndex(of: falha.uso), posicao > 0,
              let anterior = usos[ordem[posicao - 1]], anterior.comecou <= ate
        else { return falha.uso }
        return anterior.id
    }
}
