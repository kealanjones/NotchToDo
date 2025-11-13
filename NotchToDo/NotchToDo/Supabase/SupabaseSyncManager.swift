   import CoreData
import Foundation
import _Concurrency

private typealias AsyncTask = _Concurrency.Task

/// Coordinates syncing Core Data changes with Supabase. Implementation will be
/// filled in once endpoints are wired, but the scaffolding keeps integration
/// points explicit.
final class SupabaseSyncManager {
    enum State: Equatable {
        case idle
        case syncing
        case paused
        case error(String)
    }

    private enum SyncError: Error {
        case missingPayload
        case missingAccessToken
        case missingUserID
        case dependencyNotReady(String)
        case emptyResponse
    }

    private enum EntityKind {
        case orb
        case task

        init?(entityName: String) {
            switch entityName {
            case "OrbEntity":
                self = .orb
            case "TaskEntity":
                self = .task
            default:
                return nil
            }
        }

    }

    private enum PayloadWrapper {
        case orb(OrbOutboxPayload)
        case task(TaskOutboxPayload)
        case deletion(DeletionOutboxPayload)
    }

    private struct OutboxWorkItem {
        let objectID: NSManagedObjectID
        let kind: EntityKind
        let entityName: String
        let localIdentifier: UUID
        let operation: SyncOutboxOperation
        let payload: PayloadWrapper
    }

    private struct SyncOutcome {
        let remoteID: UUID?
        let remoteVersion: Int64?
    }

    struct PendingChange {
        enum Operation {
            case insert
            case update
            case delete
        }

        let entityName: String
        let identifier: UUID
        let operation: Operation
        let timestamp: Date
    }

    private let persistence: PersistenceController
    private let service: SupabaseService
    private let backgroundContext: NSManagedObjectContext
    private let queue = DispatchQueue(label: "com.notchtodo.supabase.sync", qos: .utility)
    private var accessToken: String?
    private var currentUserID: UUID?
    private var outboxObserver: NSObjectProtocol?
    weak var authManager: SupabaseAuthManager?
    private var pullTimer: DispatchSourceTimer?
    private let payloadDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private var forceFullPullNext: Bool = false

    private struct PullState {
        static let lastPullKey = "SupabaseLastSuccessfulPullAt"
        static var lastSuccessfulPullAt: Date? {
            let t = UserDefaults.standard.double(forKey: lastPullKey)
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        static func update(_ date: Date) {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: lastPullKey)
        }
    }

    private(set) var state: State = .idle {
        didSet {
            guard oldValue != state else { return }
            DebugLog.log("Sync state changed: \(oldValue) → \(state)", category: .sync)
            stateChangeHandler?(state)
        }
    }

    var stateChangeHandler: ((State) -> Void)?

    init(service: SupabaseService, persistenceController: PersistenceController = .shared) {
        self.service = service
        self.persistence = persistenceController
        self.backgroundContext = persistenceController.container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        self.backgroundContext.automaticallyMergesChangesFromParent = true
        persistenceController.registerSyncWorkerContext(backgroundContext)

        outboxObserver = NotificationCenter.default.addObserver(
            forName: .supabaseOutboxDidChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.requestImmediateSync(reason: "Outbox notification")
        }

        // Start periodic pull timer (every 10s)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 10, repeating: 10, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            // Avoid overlapping pulls while actively syncing
            if case .syncing = self.state { return }
            self.pullRemoteChanges()
        }
        timer.resume()
        pullTimer = timer
    }

    func updateAccessToken(_ token: String?) {
        accessToken = token
        if let token {
            currentUserID = Self.extractUserID(from: token)
            if currentUserID == nil {
                DebugLog.log("Unable to decode Supabase user ID from access token", category: .sync)
            }
        } else {
            currentUserID = nil
        }
    }

    deinit {
        if let token = outboxObserver {
            NotificationCenter.default.removeObserver(token)
        }
        pullTimer?.cancel()
    }

    func scheduleInitialSync() {
        queue.async { [weak self] in
            self?.performInitialSyncIfNeeded()
        }
    }

    func requestImmediateSync(reason: String) {
        queue.async { [weak self] in
            guard let self else { return }
            DebugLog.log("Immediate sync requested (\(reason))", category: .sync)
            self.flushPendingChanges()
        }
    }

    private func performInitialSyncIfNeeded() {
        guard state == .idle else { return }
        state = .syncing
        // TODO: fetch remote snapshot and merge.
        state = .idle
    }

    private func flushPendingChanges() {
        guard state != .syncing else { return }
        state = .syncing
        persistence.performOutboxMaintenanceSync()
        processOutboxBatch(limit: 50)
        // Always attempt a pull after pushing local changes
        pullRemoteChanges()
        if case .syncing = state {
            state = .idle
        }
    }

    private func pullRemoteChanges() {
        guard let accessToken else { return }
        guard let userID = currentUserID else { return }
        let since: Date? = {
            if forceFullPullNext { return nil }
            guard let last = PullState.lastSuccessfulPullAt else { return nil }
            // Apply small skew to avoid missing near-edge updates
            return last.addingTimeInterval(-5)
        }()
        do {
            try fetchAndMergeRemote(userID: userID, since: since, accessToken: accessToken)
            forceFullPullNext = false
        } catch {
            DebugLog.log("Remote pull failed to schedule: \(error)", category: .sync)
        }
    }

    // Public helper to force a full pull on next cycle
    func forceFullPullOnce() {
        queue.async { [weak self] in self?.forceFullPullNext = true }
    }

    private func fetchAndMergeRemote(userID: UUID, since: Date?, accessToken: String) throws {
        let sinceISO: String? = {
            guard let s = since else { return nil }
            return SupabaseService.iso8601FormatterWithFractional.string(from: s)
        }()

        let orbQuery: [URLQueryItem] = {
            var items = [URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)")]
            if let sinceISO { items.append(URLQueryItem(name: "updated_at", value: "gte.\(sinceISO)")) }
            items.append(URLQueryItem(name: "order", value: "updated_at.asc"))
            return items
        }()
        let taskQuery: [URLQueryItem] = {
            var items = [URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)")]
            if let sinceISO { items.append(URLQueryItem(name: "updated_at", value: "gte.\(sinceISO)")) }
            items.append(URLQueryItem(name: "order", value: "updated_at.asc"))
            return items
        }()

        queue.async { [weak self] in
            guard let self else { return }
            do {
                // ORBS pull with 401 refresh + retry
                let remoteOrbs: [OrbFetchRecord] = try awaitResult { continuation in
                    AsyncTask(priority: .utility) {
                        do {
                            var req = try self.service.makeRequest(path: "orbs", method: .get, queryItems: orbQuery, accessToken: accessToken)
                            req.setValue("return=representation", forHTTPHeaderField: "Prefer")
                            do {
                                let result: [OrbFetchRecord] = try await self.service.perform(req, decode: [OrbFetchRecord].self)
                                continuation(result, nil)
                            } catch {
                                if case let SupabaseService.ServiceError.invalidResponse(status, _) = error, status == 401 {
                                    await self.authManager?.refreshSessionIfNeeded()
                                    let newToken = self.authManager?.currentSession?.accessToken
                                    if let newToken { self.updateAccessToken(newToken) }
                                    var retryReq = try self.service.makeRequest(path: "orbs", method: .get, queryItems: orbQuery, accessToken: newToken ?? accessToken)
                                    retryReq.setValue("return=representation", forHTTPHeaderField: "Prefer")
                                    do {
                                        let retried: [OrbFetchRecord] = try await self.service.perform(retryReq, decode: [OrbFetchRecord].self)
                                        continuation(retried, nil)
                                    } catch { continuation(nil, error) }
                                } else {
                                    continuation(nil, error)
                                }
                            }
                        } catch { continuation(nil, error) }
                    }
                }

                // TASKS pull with 401 refresh + retry
                let remoteTasks: [TaskFetchRecord] = try awaitResult { continuation in
                    AsyncTask(priority: .utility) {
                        do {
                            var req = try self.service.makeRequest(path: "tasks", method: .get, queryItems: taskQuery, accessToken: accessToken)
                            req.setValue("return=representation", forHTTPHeaderField: "Prefer")
                            do {
                                let result: [TaskFetchRecord] = try await self.service.perform(req, decode: [TaskFetchRecord].self)
                                continuation(result, nil)
                            } catch {
                                if case let SupabaseService.ServiceError.invalidResponse(status, _) = error, status == 401 {
                                    await self.authManager?.refreshSessionIfNeeded()
                                    let newToken = self.authManager?.currentSession?.accessToken
                                    if let newToken { self.updateAccessToken(newToken) }
                                    var retryReq = try self.service.makeRequest(path: "tasks", method: .get, queryItems: taskQuery, accessToken: newToken ?? accessToken)
                                    retryReq.setValue("return=representation", forHTTPHeaderField: "Prefer")
                                    do {
                                        let retried: [TaskFetchRecord] = try await self.service.perform(retryReq, decode: [TaskFetchRecord].self)
                                        continuation(retried, nil)
                                    } catch { continuation(nil, error) }
                                } else {
                                    continuation(nil, error)
                                }
                            }
                        } catch { continuation(nil, error) }
                    }
                }

                DebugLog.log("Pulled \(remoteOrbs.count) orbs, \(remoteTasks.count) tasks", category: .sync)
                self.mergeRemote(orbs: remoteOrbs, tasks: remoteTasks)
                let maxOrbTime = remoteOrbs.compactMap { $0.updatedAt ?? $0.createdAt }.max()
                let maxTaskTime = remoteTasks.compactMap { $0.updatedAt ?? $0.createdAt }.max()
                if let latest = [maxOrbTime, maxTaskTime].compactMap({ $0 }).max() {
                    PullState.update(latest)
                    DebugLog.log("Updated lastSuccessfulPullAt -> \(latest)", category: .sync)
                } else {
                    DebugLog.log("No remote rows changed; lastSuccessfulPullAt unchanged", category: .sync)
                }
            } catch {
                DebugLog.log("Remote pull failed: \(error)", category: .sync)
            }
        }
    }

    private func mergeRemote(orbs: [OrbFetchRecord], tasks: [TaskFetchRecord]) {
        backgroundContext.performAndWait {
            func safeSet(_ object: NSManagedObject, key: String, value: Any?) {
                guard object.entity.attributesByName.keys.contains(key) else { return }
                object.setValue(value, forKey: key)
            }
            // Upsert orbs
            for r in orbs {
                let fetch = NSFetchRequest<OrbEntity>(entityName: "OrbEntity")
                fetch.predicate = NSPredicate(format: "remoteID == %@", r.id as CVarArg)
                fetch.fetchLimit = 1
                let entity = (try? backgroundContext.fetch(fetch).first) ?? OrbEntity(context: backgroundContext)
                safeSet(entity, key: "remoteID", value: r.id)
                if entity.value(forKey: "id") == nil { safeSet(entity, key: "id", value: r.id) }
                safeSet(entity, key: "name", value: r.name)
                safeSet(entity, key: "colorHex", value: r.colorHex)
                safeSet(entity, key: "sortOrder", value: r.sortOrder)
                safeSet(entity, key: "createdAt", value: r.createdAt)
                safeSet(entity, key: "updatedAt", value: r.updatedAt)
                safeSet(entity, key: "deletedAt", value: r.deletedAt)
                safeSet(entity, key: "remoteVersion", value: r.version)
                safeSet(entity, key: "needsSync", value: false)
                DebugLog.log("Upsert orb \(r.id.uuidString.prefix(6)) name='\(r.name)'", category: .sync)
            }

            // Upsert tasks
            for r in tasks {
                let fetch = NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
                fetch.predicate = NSPredicate(format: "remoteID == %@", r.id as CVarArg)
                fetch.fetchLimit = 1
                let task = (try? backgroundContext.fetch(fetch).first) ?? TaskEntity(context: backgroundContext)
                safeSet(task, key: "remoteID", value: r.id)
                if task.value(forKey: "id") == nil { safeSet(task, key: "id", value: r.id) }
                safeSet(task, key: "title", value: r.title)
                safeSet(task, key: "notes", value: r.notes)
                safeSet(task, key: "isCompleted", value: r.isCompleted)
                safeSet(task, key: "priority", value: r.priority)
                safeSet(task, key: "status", value: r.status)
                safeSet(task, key: "sortOrder", value: r.sortOrder)
                safeSet(task, key: "dueDate", value: r.dueDate)
                safeSet(task, key: "deletedAt", value: r.deletedAt)
                safeSet(task, key: "createdAt", value: r.createdAt)
                // TaskEntity may not have updatedAt; safeSet will no-op if absent
                safeSet(task, key: "updatedAt", value: r.updatedAt)
                safeSet(task, key: "remoteVersion", value: r.version)
                safeSet(task, key: "needsSync", value: false)

                // Link to orb by remoteID
                var linked = false
                if let orbID = r.orbId {
                    let ofetch = NSFetchRequest<OrbEntity>(entityName: "OrbEntity")
                    ofetch.predicate = NSPredicate(format: "remoteID == %@", orbID as CVarArg)
                    ofetch.fetchLimit = 1
                    if let orb = try? backgroundContext.fetch(ofetch).first {
                        if let rel = task.entity.relationshipsByName["orb"], rel.isToMany {
                            let set = task.mutableSetValue(forKey: "orb")
                            set.removeAllObjects()
                            set.add(orb)
                        } else {
                            task.setValue(orb, forKey: "orb")
                        }
                        linked = true
                    }
                }
                DebugLog.log("Upsert task \(r.id.uuidString.prefix(6)) title='\(r.title)' linked=\(linked)", category: .sync)
            }

            do {
                if backgroundContext.hasChanges { try backgroundContext.save() }
            } catch {
                DebugLog.log("Failed to save merged remote changes: \(error)", category: .sync)
                backgroundContext.reset()
            }
            // Notify UI that new data was pulled
            NotificationCenter.default.post(name: .supabaseDataDidPull, object: nil)
        }
    }

    private func fetchTaskAndMerge(id: UUID, accessToken: String) async {
        do {
            let query = [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")]
            var req = try service.makeRequest(path: "tasks", method: .get, queryItems: query, accessToken: accessToken)
            req.setValue("return=representation", forHTTPHeaderField: "Prefer")
            let records: [TaskFetchRecord] = try await service.perform(req, decode: [TaskFetchRecord].self)
            guard let record = records.first else { return }
            mergeRemote(orbs: [], tasks: [record])
        } catch {
            DebugLog.log("Post-patch fetch failed for task \(id): \(error)", category: .sync)
        }
    }

    // Utility to await inside non-async function context
    private func awaitResult<T>(_ body: (@escaping (T?, Error?) -> Void) -> Void) throws -> T {
        var result: Result<T, Error>!
        let group = DispatchGroup()
        group.enter()
        body { value, error in
            if let value { result = .success(value) } else { result = .failure(error ?? NSError(domain: "com.notchtodo", code: -1)) }
            group.leave()
        }
        group.wait()
        switch result! {
        case .success(let v): return v
        case .failure(let e): throw e
        }
    }

    private func processOutboxBatch(limit: Int) {
        guard let accessToken else {
            DebugLog.log("Supabase sync paused: missing access token", category: .sync)
            state = .paused
            return
        }
        guard let userID = currentUserID else {
            DebugLog.log("Supabase sync paused: missing user identifier", category: .sync)
            state = .paused
            return
        }

        let workItems: [OutboxWorkItem]
        do {
            workItems = try fetchOutboxWorkItems(limit: limit)
        } catch {
            DebugLog.log("Failed to fetch Supabase outbox: \(error)", category: .sync)
            backgroundContext.reset()
            state = .error("Outbox fetch failed")
            return
        }

        guard !workItems.isEmpty else { return }

        var processingError: Error?
        let group = DispatchGroup()
        group.enter()
        AsyncTask(priority: .utility) {
            do {
                try await self.process(workItems: workItems, accessToken: accessToken, userID: userID)
            } catch {
                processingError = error
            }
            group.leave()
        }
        group.wait()

        if let error = processingError {
            handleProcessingError(error)
        }
    }

    private func fetchOutboxWorkItems(limit: Int) throws -> [OutboxWorkItem] {
        var results: [OutboxWorkItem] = []
        var fetchError: Error?
        backgroundContext.performAndWait {
            let request: NSFetchRequest<SyncOutboxItem> = SyncOutboxItem.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(SyncOutboxItem.createdAt), ascending: true)]
            request.fetchLimit = limit

            do {
                let items = try backgroundContext.fetch(request)
                DebugLog.log("Fetched \(items.count) outbox items for processing", category: .sync)
                guard !items.isEmpty else { return }

                for item in items {
                    let typedName = item.entityName
                    let primitiveName = item.primitiveValue(forKey: #keyPath(SyncOutboxItem.entityName)) as? String
                    let sourceName = typedName.isEmpty ? (primitiveName ?? "") : typedName
                    let trimmed = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else {
                        DebugLog.log("Discarding outbox item with empty entity name (#\(item.id))", category: .sync)
                        backgroundContext.delete(item)
                        continue
                    }
                    guard let kind = EntityKind(entityName: trimmed) else {
                        DebugLog.log("Ignoring unsupported outbox entity \(trimmed)", category: .sync)
                        backgroundContext.delete(item)
                        continue
                    }
                    guard let operation = SyncOutboxOperation(rawValue: item.operation) else {
                        DebugLog.log("Ignoring outbox item with unknown operation \(item.operation)", category: .sync)
                        backgroundContext.delete(item)
                        continue
                    }

                    let payload: PayloadWrapper
                    do {
                        switch (kind, operation) {
                        case (.orb, .delete), (.task, .delete):
                            let deletion = try decodePayload(DeletionOutboxPayload.self, from: item.payload)
                            payload = .deletion(deletion)
                        case (.orb, _):
                            let orb = try decodePayload(OrbOutboxPayload.self, from: item.payload)
                            payload = .orb(orb)
                        case (.task, _):
                            let task = try decodePayload(TaskOutboxPayload.self, from: item.payload)
                            payload = .task(task)
                        }
                    } catch {
                        DebugLog.log("Failed to decode outbox payload for \(trimmed): \(error)", category: .sync)
                        backgroundContext.delete(item)
                        continue
                    }

                    let rawIdentifier = item.value(forKey: #keyPath(SyncOutboxItem.localIdentifier))
                    let localIdentifier: UUID
                    if let raw = rawIdentifier, let parsed = PersistenceController.parseOutboxIdentifier(raw) {
                        localIdentifier = parsed
                        item.setValue(parsed, forKey: #keyPath(SyncOutboxItem.localIdentifier))
                    } else {
                        let typeDescription = rawIdentifier.map { String(describing: type(of: $0)) } ?? "nil"
                        DebugLog.log("Discarding outbox item with invalid identifier (entity: \(trimmed), type: \(typeDescription))", category: .sync)
                        backgroundContext.delete(item)
                        continue
                    }

                    DebugLog.log("Processing outbox item: \(operation.name) \(trimmed) #\(localIdentifier.uuidString)", category: .sync)
                    let workItem = OutboxWorkItem(
                        objectID: item.objectID,
                        kind: kind,
                        entityName: trimmed,
                        localIdentifier: localIdentifier,
                        operation: operation,
                        payload: payload
                    )
                    results.append(workItem)
                }

                if backgroundContext.hasChanges {
                    try backgroundContext.save()
                }
            } catch {
                fetchError = error
            }
        }

        if let error = fetchError {
            throw error
        }

        DebugLog.log("Prepared \(results.count) outbox work items", category: .sync)
        return results
    }

    private func process(workItems: [OutboxWorkItem], accessToken: String, userID: UUID) async throws {
        // Prioritize entity dependencies: process orbs before tasks, and inserts before updates, then deletions
        let priority: (OutboxWorkItem) -> Int = { item in
            switch (item.kind, item.operation) {
            case (.orb, .insert): return 0
            case (.orb, .update): return 1
            case (.orb, .delete): return 2
            case (.task, .insert): return 3
            case (.task, .update): return 4
            case (.task, .delete): return 5
            }
        }
        let ordered = workItems.sorted { priority($0) < priority($1) }

        var firstNonDependencyError: Error?
        for workItem in ordered {
            try AsyncTask.checkCancellation()
            do {
                let outcome = try await perform(workItem: workItem, accessToken: accessToken, userID: userID)
                persistSuccess(for: workItem, outcome: outcome)
            } catch {
                // If dependency not ready (e.g., missing orb remote ID), skip for now and retry next cycle
                if let syncError = error as? SyncError, case .dependencyNotReady = syncError {
                    DebugLog.log("Deferring item due to dependency: \(workItem.entityName) #\(workItem.localIdentifier)", category: .sync)
                    continue
                }
                // Track the first substantive error but continue processing others
                if firstNonDependencyError == nil {
                    firstNonDependencyError = error
                }
            }
        }
        if let error = firstNonDependencyError {
            throw error
        }
    }

    private func perform(workItem: OutboxWorkItem, accessToken: String, userID: UUID) async throws -> SyncOutcome {
        switch (workItem.kind, workItem.operation, workItem.payload) {
        case (.orb, .insert, .orb(let payload)):
            return try await syncOrbInsert(payload, accessToken: accessToken, userID: userID)
        case (.orb, .update, .orb(let payload)):
            return try await syncOrbUpdate(payload, accessToken: accessToken, userID: userID)
        case (.orb, .delete, .deletion(let payload)):
            return try await syncOrbDelete(payload, accessToken: accessToken)
        case (.task, .insert, .task(let payload)):
            return try await syncTaskInsert(payload, accessToken: accessToken, userID: userID)
        case (.task, .update, .task(let payload)):
            return try await syncTaskUpdate(payload, accessToken: accessToken, userID: userID)
        case (.task, .delete, .deletion(let payload)):
            return try await syncTaskDelete(payload, accessToken: accessToken)
        default:
            throw SyncError.missingPayload
        }
    }

    private func persistSuccess(for workItem: OutboxWorkItem, outcome: SyncOutcome) {
        backgroundContext.performAndWait {
            if let outboxItem = try? backgroundContext.existingObject(with: workItem.objectID) as? SyncOutboxItem {
                backgroundContext.delete(outboxItem)
            }

            applyLocalPostSyncHousekeeping(
                entityName: workItem.entityName,
                identifier: workItem.localIdentifier,
                operation: workItem.operation,
                remoteID: outcome.remoteID,
                remoteVersion: outcome.remoteVersion
            )

            do {
                if backgroundContext.hasChanges {
                    try backgroundContext.save()
                }
            } catch {
                DebugLog.log("Failed to persist sync bookkeeping: \(error)", category: .sync)
                backgroundContext.reset()
            }
        }
    }

    private func handleProcessingError(_ error: Error) {
        // Handle auth expiry explicitly
        if case let SupabaseService.ServiceError.invalidResponse(status, _) = error, status == 401 {
            DebugLog.log("Supabase 401 unauthorized — attempting token refresh", category: .sync)
            AsyncTask { [weak self] in
                guard let self else { return }
                await self.authManager?.refreshSessionIfNeeded()
                // After potential refresh, request a new sync pass
                self.requestImmediateSync(reason: "JWT refresh after 401")
            }
            state = .paused
            return
        }
        if let syncError = error as? SyncError {
            switch syncError {
            case .missingAccessToken:
                DebugLog.log("Supabase sync paused: missing access token", category: .sync)
                state = .paused
            case .missingUserID:
                DebugLog.log("Supabase sync paused: unable to determine user ID", category: .sync)
                state = .paused
            case .dependencyNotReady(let reason):
                // Do not pause entire sync on transient dependency issues; items were deferred for retry
                DebugLog.log("Supabase dependency not ready: \(reason)", category: .sync)
                state = .idle
            case .emptyResponse:
                state = .error("Supabase sync conflict")
            default:
                state = .error("Supabase sync failed: \(syncError)")
            }
        } else {
            state = .error("Supabase sync failed: \(error)")
        }
    }

    private func applyLocalPostSyncHousekeeping(
        entityName: String,
        identifier: UUID,
        operation: SyncOutboxOperation,
        remoteID: UUID?,
        remoteVersion: Int64?
    ) {
        guard operation != .delete else { return }
        let trimmed = entityName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: trimmed)
        request.predicate = NSPredicate(format: "id == %@", identifier as CVarArg)
        request.fetchLimit = 1

        do {
            if let object = try backgroundContext.fetch(request).first {
                object.setValue(false, forKey: "needsSync")
                if let remoteID, object.entity.attributesByName.keys.contains("remoteID") {
                    object.setValue(remoteID, forKey: "remoteID")
                }
                if let remoteVersion, object.entity.attributesByName.keys.contains("remoteVersion") {
                    object.setValue(remoteVersion, forKey: "remoteVersion")
                }
            }
        } catch {
            DebugLog.log("Failed to mark entity synced: \(error)", category: .sync)
        }
    }

    private func syncOrbInsert(_ payload: OrbOutboxPayload, accessToken: String, userID: UUID) async throws -> SyncOutcome {
        let body = OrbInsertRequest(
            id: payload.remoteID ?? payload.localID,
            userId: userID,
            name: payload.name,
            colorHex: payload.colorHex,
            sortOrder: payload.sortOrder,
            createdAt: payload.createdAt,
            updatedAt: payload.updatedAt,
            deletedAt: payload.deletedAt
        )
        var request = try service.makeRequest(path: "orbs", method: .post, body: body, accessToken: accessToken)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        let response: [OrbRecord] = try await service.perform(request, decode: [OrbRecord].self)
        guard let record = response.first else {
            throw SyncError.emptyResponse
        }
        return SyncOutcome(remoteID: record.id, remoteVersion: record.version)
    }

    private func syncOrbUpdate(_ payload: OrbOutboxPayload, accessToken: String, userID: UUID) async throws -> SyncOutcome {
        guard let remoteID = payload.remoteID else {
            DebugLog.log("Orb update missing remote ID; performing insert instead", category: .sync)
            return try await syncOrbInsert(payload, accessToken: accessToken, userID: userID)
        }

        var queryItems = [URLQueryItem(name: "id", value: "eq.\(remoteID.uuidString)")]
        if let version = payload.remoteVersion {
            queryItems.append(URLQueryItem(name: "version", value: "eq.\(version)"))
        }

        let body = OrbUpdateRequest(
            name: payload.name,
            colorHex: payload.colorHex,
            sortOrder: payload.sortOrder,
            deletedAt: payload.deletedAt
        )

        var request = try service.makeRequest(path: "orbs", method: .patch, queryItems: queryItems, body: body, accessToken: accessToken)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        let response: [OrbRecord] = try await service.perform(request, decode: [OrbRecord].self)
        guard let record = response.first else {
            throw SyncError.emptyResponse
        }
        return SyncOutcome(remoteID: record.id, remoteVersion: record.version)
    }

    private func syncOrbDelete(_ payload: DeletionOutboxPayload, accessToken: String) async throws -> SyncOutcome {
        guard let remoteID = payload.remoteID else {
            return SyncOutcome(remoteID: nil, remoteVersion: nil)
        }
        let queryItems = [URLQueryItem(name: "id", value: "eq.\(remoteID.uuidString)")]
        let request = try service.makeRequest(path: "orbs", method: .delete, queryItems: queryItems, accessToken: accessToken)
        try await service.perform(request)
        return SyncOutcome(remoteID: remoteID, remoteVersion: nil)
    }

    private func syncTaskInsert(_ payload: TaskOutboxPayload, accessToken: String, userID: UUID) async throws -> SyncOutcome {
        guard let orbRemoteID = payload.orbRemoteID ?? resolveOrbRemoteID(for: payload.orbLocalID) else {
            throw SyncError.dependencyNotReady("Missing orb remote ID for task \(payload.localID)")
        }

        let now = Date()
        let body = TaskInsertRequest(
            id: payload.remoteID ?? payload.localID,
            userId: userID,
            orbId: orbRemoteID,
            title: payload.title,
            notes: payload.notes,
            isCompleted: payload.isCompleted,
            priority: Int16(payload.priority),
            status: payload.status,
            sortOrder: payload.sortOrder,
            dueDate: payload.dueDate,
            deletedAt: payload.deletedAt,
            createdAt: payload.createdAt,
            updatedAt: now
        )

        var request = try service.makeRequest(path: "tasks", method: .post, body: body, accessToken: accessToken)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        let response: [TaskRecord] = try await service.perform(request, decode: [TaskRecord].self)
        guard let record = response.first else {
            throw SyncError.emptyResponse
        }
        // Immediately fetch server-truth and merge locally
        await fetchTaskAndMerge(id: record.id, accessToken: accessToken)
        return SyncOutcome(remoteID: record.id, remoteVersion: record.version)
    }

    private func syncTaskUpdate(_ payload: TaskOutboxPayload, accessToken: String, userID: UUID) async throws -> SyncOutcome {
        guard let remoteID = payload.remoteID else {
            DebugLog.log("Task update missing remote ID; performing insert instead", category: .sync)
            return try await syncTaskInsert(payload, accessToken: accessToken, userID: userID)
        }

        guard let orbRemoteID = payload.orbRemoteID ?? resolveOrbRemoteID(for: payload.orbLocalID) else {
            throw SyncError.dependencyNotReady("Missing orb remote ID for task \(payload.localID)")
        }

        var queryItems = [URLQueryItem(name: "id", value: "eq.\(remoteID.uuidString)")]
        if let version = payload.remoteVersion {
            queryItems.append(URLQueryItem(name: "version", value: "eq.\(version)"))
        }

        let body = TaskUpdateRequest(
            orbId: orbRemoteID,
            title: payload.title,
            notes: payload.notes,
            isCompleted: payload.isCompleted,
            priority: Int16(payload.priority),
            status: payload.status,
            sortOrder: payload.sortOrder,
            dueDate: payload.dueDate,
            deletedAt: payload.deletedAt,
            updatedAt: Date()
        )

        var request = try service.makeRequest(path: "tasks", method: .patch, queryItems: queryItems, body: body, accessToken: accessToken)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        let response: [TaskRecord] = try await service.perform(request, decode: [TaskRecord].self)
        guard let record = response.first else {
            throw SyncError.emptyResponse
        }
        // Immediately fetch server-truth and merge locally
        await fetchTaskAndMerge(id: record.id, accessToken: accessToken)
        return SyncOutcome(remoteID: record.id, remoteVersion: record.version)
    }

    private func syncTaskDelete(_ payload: DeletionOutboxPayload, accessToken: String) async throws -> SyncOutcome {
        guard let remoteID = payload.remoteID else {
            return SyncOutcome(remoteID: nil, remoteVersion: nil)
        }
        let queryItems = [URLQueryItem(name: "id", value: "eq.\(remoteID.uuidString)")]
        let request = try service.makeRequest(path: "tasks", method: .delete, queryItems: queryItems, accessToken: accessToken)
        try await service.perform(request)
        return SyncOutcome(remoteID: remoteID, remoteVersion: nil)
    }

    private func resolveOrbRemoteID(for localID: UUID) -> UUID? {
        var remoteID: UUID?
        backgroundContext.performAndWait {
            let request: NSFetchRequest<OrbEntity> = OrbEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", localID as CVarArg)
            request.fetchLimit = 1
            do {
                remoteID = try backgroundContext.fetch(request).first?.remoteID
            } catch {
                DebugLog.log("Failed to resolve orb remote ID: \(error)", category: .sync)
            }
        }
        return remoteID
    }

    private func decodePayload<T: Decodable>(_ type: T.Type, from data: Data?) throws -> T {
        guard let data else {
            throw SyncError.missingPayload
        }
        return try payloadDecoder.decode(T.self, from: data)
    }
}

private extension SupabaseSyncManager {
    static func extractUserID(from token: String) -> UUID? {
        let components = token.split(separator: ".")
        guard components.count >= 2 else { return nil }
        let payloadPart = String(components[1])
        var padded = payloadPart
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = padded.count % 4
        if remainder > 0 {
            padded.append(String(repeating: "=", count: 4 - remainder))
        }

        guard let data = Data(base64Encoded: padded),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else {
            return nil
        }
        return UUID(uuidString: sub)
    }
}

private struct OrbInsertRequest: Encodable {
    let id: UUID
    let userId: UUID
    let name: String
    let colorHex: String
    let sortOrder: Double
    let createdAt: Date
    let updatedAt: Date?
    let deletedAt: Date?
}

private struct OrbUpdateRequest: Encodable {
    let name: String
    let colorHex: String
    let sortOrder: Double
    let deletedAt: Date?
}

private struct TaskInsertRequest: Encodable {
    let id: UUID
    let userId: UUID
    let orbId: UUID
    let title: String
    let notes: String?
    let isCompleted: Bool
    let priority: Int16
    let status: Int16
    let sortOrder: Double
    let dueDate: Date?
    let deletedAt: Date?
    let createdAt: Date
    let updatedAt: Date?
}

private struct TaskUpdateRequest: Encodable {
    let orbId: UUID
    let title: String
    let notes: String?
    let isCompleted: Bool
    let priority: Int16
    let status: Int16
    let sortOrder: Double
    let dueDate: Date?
    let deletedAt: Date?
    let updatedAt: Date?
}

private struct OrbRecord: Decodable {
    let id: UUID
    let version: Int64
}

private struct TaskRecord: Decodable {
    let id: UUID
    let version: Int64
}

// Payloads for remote→local fetch
private struct OrbFetchRecord: Decodable {
    let id: UUID
    let userId: UUID
    let name: String
    let colorHex: String
    let sortOrder: Double
    let createdAt: Date
    let updatedAt: Date?
    let deletedAt: Date?
    let version: Int64
}

private struct TaskFetchRecord: Decodable {
    let id: UUID
    let userId: UUID
    let orbId: UUID?
    let title: String
    let notes: String?
    let isCompleted: Bool
    let priority: Int16
    let status: Int16
    let sortOrder: Double
    let dueDate: Date?
    let deletedAt: Date?
    let createdAt: Date
    let updatedAt: Date?
    let version: Int64
}
