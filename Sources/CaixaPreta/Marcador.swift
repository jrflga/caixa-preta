import Foundation

/// O que se sabe do uso atual na última vez que ele deu sinal. Na abertura
/// seguinte, vira `sessao.anterior`.
struct MarcaDoUso: Codable, Equatable {
    var uso: String
    var comecou: Date
    /// `abrindo`, `frente` ou `fundo`.
    var estado: String
    var atualizado: Date
    var memoriaMB: Int
    var picoMB: Int
}

/// O arquivo `uso-atual.json`. Marcador estragado conta como não havendo.
struct Marcador {
    let arquivo: URL

    func ler() -> MarcaDoUso? {
        guard let dados = try? Data(contentsOf: arquivo) else { return nil }
        return try? JSONDecoder().decode(MarcaDoUso.self, from: dados)
    }

    func gravar(_ marca: MarcaDoUso) {
        guard let dados = try? JSONEncoder().encode(marca) else { return }
        try? dados.write(to: arquivo, options: Diario.opcoesDeEscrita)
    }
}
