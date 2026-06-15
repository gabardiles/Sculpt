import Foundation
import Supabase

/// Reads the Supabase connection from Info.plist (injected via Config.xcconfig).
/// The host is stored without a scheme because xcconfig treats `//` as a
/// comment; we prepend https:// here.
enum SupabaseConfig {
    static var url: URL {
        let host = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_HOST") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let full = host.hasPrefix("http") ? host : "https://\(host)"
        guard let u = URL(string: full), host.isEmpty == false, host != "your-project.supabase.co" else {
            fatalError("""
            Supabase is not configured. Edit ios/Sculpt/Config.xcconfig and set
            SUPABASE_HOST and SUPABASE_ANON_KEY (Supabase → Project Settings → API).
            """)
        }
        return u
    }
    static var anonKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String) ?? ""
    }
}

/// Single shared Supabase client, configured to encode/decode snake_case JSON
/// against camelCase Swift models.
@MainActor
final class Supa {
    static let shared = Supa()
    let client: SupabaseClient

    private init() {
        let decoder: JSONDecoder = {
            let d = JSONDecoder()
            d.keyDecodingStrategy = .convertFromSnakeCase
            return d
        }()
        let encoder: JSONEncoder = {
            let e = JSONEncoder()
            e.keyEncodingStrategy = .convertToSnakeCase
            return e
        }()
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: SupabaseClientOptions(
                db: SupabaseClientOptions.DatabaseOptions(encoder: encoder, decoder: decoder)
            )
        )
    }
}
