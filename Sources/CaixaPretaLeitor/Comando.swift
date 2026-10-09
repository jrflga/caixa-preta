import CaixaPretaFormato
import Foundation

/// De onde o comando lê e como roda as ferramentas. Nos testes, tudo inventado.
public struct Contexto {
    public var raiz = Localizador.raizPadrao
    public var agora = Date()
    public var fuso = TimeZone.current
    public var baixar: (URL) -> Void = baixarComBrctl
    public var rodar: Simbolizador.Rodar = rodarDeVerdade
    public var arquivosDoXcode = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Developer/Xcode/Archives", directoryHint: .isDirectory)

    public init() {}
}

/// O comando `caixa-preta`, fora do `main` para os testes rodarem.
public enum Comando {
    public static let ajuda = """
        Uso:
          caixa-preta resumo <App> [--dias 1] [--simbolos <pasta>] [--arquivo <arquivo enviado>]
          caixa-preta eventos <App> [--dias 1] [--uso <id>] [--desde 14:30] [--arquivo <arquivo enviado>]
          caixa-preta simbolo <uuid> <deslocamento> [--simbolos <pasta>]

        Lê ~/Library/Mobile Documents/iCloud~*/Documents/CaixaPreta/. Os dSYMs vêm
        de --simbolos e de ~/Library/Developer/Xcode/Archives.

        """

    /// Roda e devolve o código de saída; o texto vai para `escrever`.
    public static func rodar(_ argumentos: [String], contexto: Contexto = Contexto(), escrever: (String) -> Void) -> Int32 {
        let opcoes = Opcoes(Array(argumentos.dropFirst()))
        if let invalida = opcoes.invalida {
            escrever("Opção desconhecida ou sem valor: \(invalida)\n\n\(ajuda)")
            return 2
        }
        var contexto = contexto
        if let raiz = opcoes["--raiz"] { contexto.raiz = URL(filePath: raiz, directoryHint: .isDirectory) }
        switch (argumentos.first ?? "", opcoes.posicionais.count) {
        case ("resumo", 1), ("eventos", 1):
            return ler(argumentos[0], app: opcoes.posicionais[0], opcoes: opcoes, contexto: contexto, escrever: escrever)
        case ("simbolo", 2):
            return simbolo(opcoes: opcoes, contexto: contexto, escrever: escrever)
        default:
            escrever(ajuda)
            return 2
        }
    }

    private static func ler(_ subcomando: String, app: String, opcoes: Opcoes, contexto: Contexto, escrever: (String) -> Void) -> Int32 {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = contexto.fuso
        var fontes: [(titulo: String, registros: Registros)] = []
        var desde = Date.distantPast
        if let arquivo = opcoes["--arquivo"] {
            let url = URL(filePath: arquivo)
            fontes = [(titulo: url.lastPathComponent, registros: Leitura.ler(arquivoEnviado: url))]
        } else {
            let quantos = max(opcoes.inteiro("--dias") ?? 1, 1)
            // O resumo lê um dia a mais: o uso que fecha de um dia para o outro
            // só é contado na abertura seguinte.
            let lidos = subcomando == "resumo" ? quantos + 1 : quantos
            let primeiro = calendario.date(byAdding: .day, value: -(quantos - 1), to: contexto.agora) ?? contexto.agora
            desde = calendario.startOfDay(for: primeiro)
            let dias = Set((0..<lidos)
                .compactMap { calendario.date(byAdding: .day, value: -$0, to: contexto.agora) }
                .map { Dia.nome($0, calendario: calendario) })
            let pastas = Localizador.pastas(doApp: app, raiz: contexto.raiz, baixar: contexto.baixar)
            guard !pastas.isEmpty else {
                escrever("Nenhuma pasta da CaixaPreta com usos do \(app) em \(contexto.raiz.path).\n")
                return 1
            }
            fontes = pastas.map { (titulo: "\(app) · aparelho \($0.lastPathComponent)", registros: Leitura.ler(pasta: $0, dias: dias)) }
        }
        if subcomando == "resumo" {
            let simbolizador = Simbolizador(pastas: pastasDeSimbolos(opcoes, contexto), rodar: contexto.rodar)
            for fonte in fontes {
                escrever(Resumo.texto(
                    titulo: fonte.titulo, registros: fonte.registros, simbolizador: simbolizador, fuso: contexto.fuso, desde: desde
                ))
            }
        } else {
            let formato = Formato(fuso: contexto.fuso)
            let desde = opcoes["--desde"].flatMap { horaDeHoje($0, agora: contexto.agora, calendario: calendario) } ?? .distantPast
            let uso = opcoes["--uso"]
            for fonte in fontes {
                escrever(fonte.titulo + "\n")
                for evento in fonte.registros.eventos where evento.hora >= desde && (uso == nil || evento.uso == uso) {
                    escrever(formato.linhaCompleta(evento) + "\n")
                }
            }
        }
        return 0
    }

    private static func simbolo(opcoes: Opcoes, contexto: Contexto, escrever: (String) -> Void) -> Int32 {
        let uuid = opcoes.posicionais[0]
        let texto = opcoes.posicionais[1]
        guard let deslocamento = texto.hasPrefix("0x") ? Int(texto.dropFirst(2), radix: 16) : Int(texto) else {
            escrever(ajuda)
            return 2
        }
        let simbolizador = Simbolizador(pastas: pastasDeSimbolos(opcoes, contexto), rodar: contexto.rodar)
        guard let nome = simbolizador.nome(Quadro(binario: "?", uuid: uuid, deslocamento: deslocamento)) else {
            escrever("Sem dSYM com o UUID \(uuid), ou o endereço não tem nome.\n")
            return 1
        }
        escrever(nome + "\n")
        return 0
    }

    private static func pastasDeSimbolos(_ opcoes: Opcoes, _ contexto: Contexto) -> [URL] {
        opcoes.todos("--simbolos").map { URL(filePath: $0, directoryHint: .isDirectory) } + [contexto.arquivosDoXcode]
    }

    /// "14:30" → hoje às 14:30, no fuso do comando.
    static func horaDeHoje(_ texto: String, agora: Date, calendario: Calendar) -> Date? {
        let partes = texto.split(separator: ":").compactMap { Int($0) }
        guard partes.count == 2 else { return nil }
        return calendario.date(bySettingHour: partes[0], minute: partes[1], second: 0, of: agora)
    }
}

/// Os argumentos depois do subcomando: posicionais e `--nome valor`.
struct Opcoes {
    static let conhecidas: Set = ["--dias", "--simbolos", "--arquivo", "--raiz", "--uso", "--desde"]

    private(set) var posicionais: [String] = []
    private var valores: [String: [String]] = [:]
    private(set) var invalida: String?

    init(_ argumentos: [String]) {
        var resto = argumentos[...]
        while let atual = resto.popFirst() {
            guard atual.hasPrefix("--") else {
                posicionais.append(atual)
                continue
            }
            guard Self.conhecidas.contains(atual), let valor = resto.popFirst() else {
                invalida = atual
                return
            }
            valores[atual, default: []].append(valor)
        }
    }

    subscript(nome: String) -> String? { valores[nome]?.last }

    func todos(_ nome: String) -> [String] { valores[nome] ?? [] }

    func inteiro(_ nome: String) -> Int? { self[nome].flatMap { Int($0) } }
}
