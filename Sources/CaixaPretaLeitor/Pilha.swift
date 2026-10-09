import Foundation

/// Um quadro da pilha: o binário, o UUID dele e o deslocamento no segmento
/// de texto.
public struct Quadro: Equatable, Sendable {
    public let binario: String
    public let uuid: String
    public let deslocamento: Int

    public init(binario: String, uuid: String, deslocamento: Int) {
        self.binario = binario
        self.uuid = uuid
        self.deslocamento = deslocamento
    }
}

public enum Pilha {
    /// Os quadros da linha de execução culpada (`threadAttributed`), na ordem
    /// em que o MetricKit entrega, até 64.
    public static func quadros(_ json: Data, chave: String, indice: Int) -> [Quadro] {
        guard let raiz = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any],
              let lista = raiz[chave] as? [[String: Any]], lista.indices.contains(indice),
              let arvore = lista[indice]["callStackTree"] as? [String: Any],
              let pilhas = arvore["callStacks"] as? [[String: Any]]
        else { return [] }
        let culpada = pilhas.first { $0["threadAttributed"] as? Bool == true } ?? pilhas.first
        var atual = (culpada?["callStackRootFrames"] as? [[String: Any]])?.first
        var quadros: [Quadro] = []
        while let quadro = atual, quadros.count < 64 {
            quadros.append(Quadro(
                binario: quadro["binaryName"] as? String ?? "?",
                uuid: quadro["binaryUUID"] as? String ?? "",
                deslocamento: quadro["offsetIntoBinaryTextSegment"] as? Int ?? 0
            ))
            atual = (quadro["subFrames"] as? [[String: Any]])?.first
        }
        return quadros
    }
}
