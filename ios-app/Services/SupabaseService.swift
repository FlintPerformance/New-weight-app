import Foundation

/// Supabase client configuration and API wrapper.
///
/// Dependencies: Add `supabase-swift` package
/// https://github.com/supabase/supabase-swift
///
/// Setup:
/// 1. Add SPM dependency: https://github.com/supabase/supabase-swift
/// 2. Set SUPABASE_URL and SUPABASE_ANON_KEY in environment or config
/// 3. Initialize client in app startup
enum SupabaseConfig {
    // TODO: Move to environment/config
    static let url = "https://YOUR_PROJECT.supabase.co"
    static let anonKey = "YOUR_ANON_KEY"
}

/// Lightweight wrapper — actual Supabase SDK handles most of the work.
/// This just centralizes the configuration and common queries.
///
/// Example usage with supabase-swift SDK:
///
/// ```swift
/// import Supabase
///
/// let client = SupabaseClient(
///     supabaseURL: URL(string: SupabaseConfig.url)!,
///     supabaseKey: SupabaseConfig.anonKey
/// )
///
/// // Auth
/// try await client.auth.signUp(email: email, password: password)
/// try await client.auth.signIn(email: email, password: password)
/// try await client.auth.signInWithApple(idToken: token)
///
/// // Data
/// let weights: [WeightRow] = try await client.from("weights")
///     .select()
///     .eq("user_id", value: userId)
///     .order("date", ascending: false)
///     .execute()
///     .value
///
/// try await client.from("weights")
///     .insert(weightRow)
///     .execute()
///
/// // Storage (avatars)
/// try await client.storage.from("avatars")
///     .upload(path: "\(userId)/avatar.webp", file: imageData)
///
/// // Realtime (circle feed)
/// let channel = client.channel("circle-feed")
/// channel.on("postgres_changes", filter: .init(event: .insert, schema: "public", table: "circle_feed")) { payload in
///     // Handle new feed entry
/// }
/// await channel.subscribe()
/// ```
enum SupabaseService {
    // Client would be initialized here when SDK is added
    // static let client = SupabaseClient(...)
}
