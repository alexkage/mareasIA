import Foundation

enum TideRepositoryError: LocalizedError, Equatable {
    case networkError
    case invalidData
    case unauthorized
    case missingAPIKey
    case cityNotFound
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Error de red al consultar la API de mareas."
        case .invalidData:
            return "Los datos recibidos no son validos."
        case .unauthorized:
            return "La API key de Stormglass no es valida."
        case .missingAPIKey:
            return "Falta la API key. Copia Secrets.example.plist a Secrets.plist e introduce tu clave."
        case .cityNotFound:
            return "Ciudad no encontrada."
        case .unknown(let message):
            return message
        }
    }
}
