import Foundation
import Supabase

/// Reads the Supabase connection from Info.plist (injected via Config.xcconfig).
/// The host is stored without a scheme because xcconfig treats `//` as a
/// comment; we prepend https:// here.
enum SupabaseConfig {
    static var url: URL {
        // Strip any scheme the value may carry. xcconfig also treats `//` as a
        // comment, so a pasted `https://host` is silently truncated to `https:`
        // — strip that leftover too so a misconfig fails loudly below instead of
        // building a hostless URL that hangs every request (a blank-screen app).
        let host = ((Bundle.main.object(forInfoDictionaryKey: "SUPABASE_HOST") as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https:", with: "")
            .replacingOccurrences(of: "http:", with: "")
            .replacingOccurrences(of: "/", with: "")
        guard host.contains("."), host != "your-project.supabase.co",
              let u = URL(string: "https://\(host)") else {
            fatalError("""
            Supabase is not configured (host=\"\(host)\"). Edit ios/Sculpt/Config.xcconfig
            and set SUPABASE_HOST to your project host WITHOUT the scheme — e.g.
            SUPABASE_HOST = your-project.supabase.co  (not https://…, the `//` is a
            comment in xcconfig). Set SUPABASE_ANON_KEY too (Supabase → Settings → API).
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
