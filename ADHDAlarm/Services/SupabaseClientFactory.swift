import Foundation
@preconcurrency import Supabase

/// Supabaseクライアントを全サービスで共有するファクトリ
/// SupabaseSOSService と FamilyRemoteService が同じセッションを使う
enum SupabaseClientFactory {
    static let shared: SupabaseClient = SupabaseClient(
        supabaseURL: URL(string: Constants.Supabase.projectURL)!,
        supabaseKey: Constants.Supabase.anonKey
    )
}
