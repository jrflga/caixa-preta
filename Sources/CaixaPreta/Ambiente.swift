import Foundation

/// O que a caixa sabe do app e do aparelho, e de onde vêm a hora e a
/// memória. Nos testes, tudo isso é inventado.
struct Ambiente: Sendable {
    var app: String
    var versao: String
    var build: String
    var ios: String
    var modelo: String
    var agora: @Sendable () -> Date
    var memoriaEmMB: @Sendable () -> Int
}
