import Foundation
import Supabase

/// Central Supabase client used across the app.
enum SupabaseService {
    static let client: SupabaseClient = {
        guard let url = URL(string: SupabaseConfig.projectURL) else {
            fatalError("Invalid SupabaseConfig.projectURL")
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: SupabaseConfig.anonKey
        )
    }()
}

