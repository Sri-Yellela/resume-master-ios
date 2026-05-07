import Foundation
@MainActor final class JobQueue: ObservableObject { @Published private(set) var queuedJobs:[Job]=[]; func enqueue(_ job:Job){if !queuedJobs.contains(where:{$0.id==job.id}){queuedJobs.append(job)}}; func remove(_ job:Job){queuedJobs.removeAll{$0.id==job.id}}; func clearCompleted(){queuedJobs.removeAll()} }
