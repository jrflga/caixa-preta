import CaixaPretaLeitor
import Foundation

exit(Comando.rodar(Array(CommandLine.arguments.dropFirst())) { print($0, terminator: "") })
