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

extension Ambiente {
    /// O app e o aparelho de verdade.
    static func doAparelho(app: String) -> Ambiente {
        let info = Bundle.main.infoDictionary ?? [:]
        let sistema = ProcessInfo.processInfo.operatingSystemVersion
        let ios = "\(sistema.majorVersion).\(sistema.minorVersion)" + (sistema.patchVersion > 0 ? ".\(sistema.patchVersion)" : "")
        return Ambiente(
            app: app,
            versao: info["CFBundleShortVersionString"] as? String ?? "?",
            build: info["CFBundleVersion"] as? String ?? "?",
            ios: ios,
            modelo: Medidas.modelo(),
            agora: { Date() },
            memoriaEmMB: { Medidas.memoriaEmMB() }
        )
    }
}

/// Medidas do próprio processo.
enum Medidas {
    /// A "pegada" do app (`phys_footprint`), em MB: o número que o iOS usa
    /// para fechar o app por memória.
    static func memoriaEmMB() -> Int {
        var info = task_vm_info_data_t()
        var quantidade = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let resultado = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(quantidade)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &quantidade)
            }
        }
        guard resultado == KERN_SUCCESS else { return 0 }
        return Int(info.phys_footprint / 1_048_576)
    }

    /// "iPhone15,4". No simulador, o modelo simulado; no Mac, "arm64".
    static func modelo() -> String {
        if let simulado = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulado }
        var sistema = utsname()
        uname(&sistema)
        return withUnsafeBytes(of: &sistema.machine) { bytes in
            String(decoding: bytes.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }
}
