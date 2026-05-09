import Foundation

// Matches the normalized job schema from services/jobs/schema.js
struct Job: Codable, Identifiable {
  let id: String
  let title: String
  let company: String
  let location: String
  let url: String
  let source: String
  let description: String?
  let salary_min: Double?
  let salary_max: Double?
  let salary_currency: String?
  let posted_at: String?
  let contract_type: String?
  let remote: Bool?
}

struct JobAttribution: Codable {
  let name: String
  let url: String
}

struct JobSearchResponse: Codable {
  let success: Bool
  let jobs: [Job]
  let total: Int
  let page: Int
  let pageSize: Int
  let sources: [String]
  let attribution: [JobAttribution]
}

struct JobSearchParams {
  var query: String    = ""
  var location: String = ""
  var country: String  = "us"
  var page: Int        = 1
  var pageSize: Int    = 10
}

@MainActor
class JobRepository: ObservableObject {
  static let shared = JobRepository()

  private let baseURL = "https://resumemaster.one"
  // For local dev: "http://localhost:3000"

  @Published var jobs: [Job] = []
  @Published var total: Int = 0
  @Published var attribution: [JobAttribution] = []
  @Published var isLoading: Bool = false
  @Published var error: String? = nil

  func search(params: JobSearchParams) async {
    isLoading = true
    error = nil

    var components = URLComponents(string: "\(baseURL)/api/jobs")!
    components.queryItems = [
      URLQueryItem(name: "q",        value: params.query),
      URLQueryItem(name: "location", value: params.location),
      URLQueryItem(name: "country",  value: params.country),
      URLQueryItem(name: "page",     value: String(params.page)),
      URLQueryItem(name: "pageSize", value: String(params.pageSize)),
    ].filter { !($0.value?.isEmpty ?? true) }

    guard let url = components.url else {
      error = "Invalid search parameters."
      isLoading = false
      return
    }

    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      let response  = try JSONDecoder().decode(JobSearchResponse.self, from: data)
      jobs        = response.jobs
      total       = response.total
      attribution = response.attribution
    } catch {
      self.error = "Could not load jobs. Please try again."
      print("[JobRepository] Error:", error)
    }

    isLoading = false
  }
}
