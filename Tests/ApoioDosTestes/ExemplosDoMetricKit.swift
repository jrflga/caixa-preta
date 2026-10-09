import Foundation

/// Relatórios do MetricKit no formato do `jsonRepresentation()`, com dados
/// inventados.
public enum ExemplosDoMetricKit {
    /// Uma falha às 14:31 de Brasília: sinal 11, na linha de execução culpada
    /// (a segunda), com três quadros.
    public static let falha = Data("""
    {
      "timeStampBegin" : "2026-10-09 17:31:00 +0000",
      "timeStampEnd" : "2026-10-09 17:31:00 +0000",
      "crashDiagnostics" : [
        {
          "version" : "1.0.0",
          "callStackTree" : {
            "callStackPerThread" : true,
            "callStacks" : [
              {
                "threadAttributed" : false,
                "callStackRootFrames" : [
                  { "binaryUUID" : "11111111-2222-3333-4444-555555555555", "offsetIntoBinaryTextSegment" : 4096,
                    "sampleCount" : 1, "binaryName" : "libsystem_kernel.dylib", "address" : 7000000000 }
                ]
              },
              {
                "threadAttributed" : true,
                "callStackRootFrames" : [
                  {
                    "binaryUUID" : "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", "offsetIntoBinaryTextSegment" : 16,
                    "sampleCount" : 1, "binaryName" : "Exemplo", "address" : 4294967312,
                    "subFrames" : [
                      {
                        "binaryUUID" : "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", "offsetIntoBinaryTextSegment" : 32,
                        "sampleCount" : 1, "binaryName" : "Exemplo", "address" : 4294967328,
                        "subFrames" : [
                          { "binaryUUID" : "12121212-3434-5656-7878-909090909090", "offsetIntoBinaryTextSegment" : 1024,
                            "sampleCount" : 1, "binaryName" : "WebKit", "address" : 7100000000 }
                        ]
                      }
                    ]
                  }
                ]
              }
            ]
          },
          "diagnosticMetaData" : {
            "appBuildVersion" : "20261009.1513",
            "appVersion" : "0.2.0",
            "bundleIdentifier" : "app.exemplo",
            "deviceType" : "iPhone15,4",
            "exceptionCode" : 0,
            "exceptionType" : 1,
            "isTestFlightApp" : true,
            "osVersion" : "iPhone OS 27.0 (24A5000a)",
            "platformArchitecture" : "arm64",
            "signal" : 11,
            "terminationReason" : "Namespace SIGNAL, Code 11 Segmentation fault: 11"
          }
        }
      ]
    }
    """.utf8)

    /// Um travamento de 2,5 s às 14:20 de Brasília.
    public static let travamento = Data("""
    {
      "timeStampBegin" : "2026-10-09 17:20:00 +0000",
      "timeStampEnd" : "2026-10-09 17:20:00 +0000",
      "hangDiagnostics" : [
        {
          "version" : "1.0.0",
          "callStackTree" : { "callStackPerThread" : false, "callStacks" : [] },
          "diagnosticMetaData" : { "appBuildVersion" : "20261009.1513", "appVersion" : "0.2.0", "hangDuration" : "2.5 sec" }
        }
      ]
    }
    """.utf8)

    /// A contagem de um dia: 1 acesso inválido na frente; 5 normais e 2 por
    /// limite de memória no fundo.
    public static let metricas = Data("""
    {
      "timeStampBegin" : "2026-10-08 03:00:00 +0000",
      "timeStampEnd" : "2026-10-09 02:59:00 +0000",
      "applicationExitMetrics" : {
        "foregroundExitData" : {
          "cumulativeNormalAppExitCount" : 0, "cumulativeMemoryResourceLimitExitCount" : 0,
          "cumulativeBadAccessExitCount" : 1, "cumulativeAbnormalExitCount" : 0,
          "cumulativeIllegalInstructionExitCount" : 0, "cumulativeAppWatchdogExitCount" : 0
        },
        "backgroundExitData" : {
          "cumulativeNormalAppExitCount" : 5, "cumulativeMemoryResourceLimitExitCount" : 2,
          "cumulativeMemoryPressureExitCount" : 0, "cumulativeSuspendedWithLockedFileExitCount" : 0,
          "cumulativeAppWatchdogExitCount" : 0, "cumulativeBackgroundTaskAssertionTimeoutExitCount" : 0
        }
      }
    }
    """.utf8)
}
