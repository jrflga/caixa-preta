@testable import CaixaPreta
import Testing

@Suite("Medidas do processo")
struct MedidasTests {
    @Test("a memória do próprio processo é medida em MB")
    func memoria() {
        #expect(Medidas.memoriaEmMB() > 0)
        #expect(Medidas.memoriaEmMB() < 100_000)
    }

    @Test("o ambiente de verdade traz o modelo e a versão do sistema")
    func ambiente() {
        let ambiente = Ambiente.doAparelho(app: "Exemplo")
        #expect(ambiente.app == "Exemplo")
        #expect(!ambiente.modelo.isEmpty)
        #expect(ambiente.ios.wholeMatch(of: /\d+\.\d+(\.\d+)?/) != nil)
        #expect(ambiente.memoriaEmMB() > 0)
    }
}
