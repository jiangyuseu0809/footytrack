import SwiftUI
import MapKit
import CoreLocation

struct LocationEditorView: View {
    let session: FootballSession
    @ObservedObject var store: SessionStore
    let trackPoints: [TrackPointRecord]

    @Environment(\.dismiss) private var dismiss
    @State private var editText: String = ""
    @State private var nearbyFields: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    /// Keywords that identify a venue as a football/soccer field
    private static let footballKeywords = [
        "足球", "soccer", "football", "球场", "绿茵", "草坪球场"
    ]

    /// Keywords for venues that are NOT football fields
    private static let excludeKeywords = [
        "篮球", "网球", "羽毛球", "乒乓", "排球", "棒球", "高尔夫",
        "游泳", "健身", "瑜伽", "拳击", "台球", "保龄球", "壁球",
        "basketball", "tennis", "badminton", "golf", "swimming", "gym",
        "baseball", "volleyball", "bowling", "squash"
    ]

    private var coordinate: CLLocationCoordinate2D? {
        if session.locationLatitude != 0 || session.locationLongitude != 0 {
            return CLLocationCoordinate2D(latitude: session.locationLatitude, longitude: session.locationLongitude)
        }
        if let first = trackPoints.first {
            return CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        currentLocationCard
                        manualInputSection
                        nearbyFieldsSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("修改场地")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .task {
                editText = session.locationName
                await searchNearbyFields(query: nil)
            }
        }
    }

    // MARK: - Current Location Card

    private var currentLocationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前场地")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: 10) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: 0xA855F7))
                Text(session.locationName.isEmpty ? "未知位置" : session.locationName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }
        }
        .padding(16)
        .background(AppColors.cardBg)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Manual Input

    private var manualInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("搜索球场")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                    TextField("输入足球场名称搜索", text: $editText)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textPrimary)
                        .autocorrectionDisabled()
                    if !editText.isEmpty {
                        Button {
                            editText = ""
                            triggerSearch(query: nil)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)

                Button {
                    guard !editText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    session.locationName = editText.trimmingCharacters(in: .whitespaces)
                    try? store.context.save()
                    dismiss()
                } label: {
                    Text("确定")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(hex: 0xA855F7))
                        .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBg)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .onChange(of: editText) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                triggerSearch(query: nil)
            } else {
                triggerSearch(query: trimmed)
            }
        }
    }

    // MARK: - Nearby Fields

    private var nearbyFieldsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("附近足球场")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                if isSearching {
                    ProgressView()
                        .tint(AppColors.textSecondary)
                        .scaleEffect(0.7)
                }
            }

            if nearbyFields.isEmpty && !isSearching {
                Text("未找到附近的足球场")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(nearbyFields.enumerated()), id: \.offset) { _, item in
                    fieldRow(item: item)
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBg)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func fieldRow(item: MKMapItem) -> some View {
        let name = item.name ?? "未知球场"
        let distance: String = {
            guard let coord = coordinate, let itemLoc = item.placemark.location else { return "" }
            let dist = CLLocation(latitude: coord.latitude, longitude: coord.longitude).distance(from: itemLoc)
            if dist < 1000 {
                return String(format: "%.0fm", dist)
            } else {
                return String(format: "%.1fkm", dist / 1000)
            }
        }()

        return Button {
            session.locationName = name
            try? store.context.save()
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: 0x10B981))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                    if let address = item.placemark.title, !address.isEmpty, address != name {
                        Text(address)
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if !distance.isEmpty {
                    Text(distance)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search

    /// Debounced search trigger
    private func triggerSearch(query: String?) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            await searchNearbyFields(query: query)
        }
    }

    private func searchNearbyFields(query: String?) async {
        guard let coord = coordinate else { return }
        isSearching = true
        defer { isSearching = false }

        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)

        // Base queries always search for football fields
        var searchQueries = ["足球场", "足球", "soccer field", "football field"]

        // If user typed something, add it as an additional query
        if let query = query, !query.isEmpty {
            searchQueries.insert(query, at: 0)
            // Also combine user query with football keyword
            if !query.contains("足球") && !query.lowercased().contains("football") && !query.lowercased().contains("soccer") {
                searchQueries.insert("\(query) 足球", at: 1)
            }
        }

        var allItems: [MKMapItem] = []
        var seenNames = Set<String>()

        for q in searchQueries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = q
            request.region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 5000,
                longitudinalMeters: 5000
            )
            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                guard !Task.isCancelled else { return }
                for item in response.mapItems {
                    guard let name = item.name, !seenNames.contains(name) else { continue }
                    seenNames.insert(name)
                    allItems.append(item)
                }
            } catch {
                continue
            }
        }

        guard !Task.isCancelled else { return }

        // Filter: only keep items that look like football/soccer venues
        let filtered = allItems.filter { item in
            isFootballVenue(item: item)
        }

        // Sort: keyword-matching results first, then by distance
        let userQuery = query?.lowercased().trimmingCharacters(in: .whitespaces) ?? ""
        let sorted = filtered.sorted { a, b in
            let nameA = (a.name ?? "").lowercased()
            let nameB = (b.name ?? "").lowercased()

            // If user has input, prioritize name matches
            if !userQuery.isEmpty {
                let matchA = nameA.contains(userQuery) || userQuery.split(separator: " ").allSatisfy { nameA.contains($0) }
                let matchB = nameB.contains(userQuery) || userQuery.split(separator: " ").allSatisfy { nameB.contains($0) }
                if matchA && !matchB { return true }
                if !matchA && matchB { return false }
            }

            // Then sort by distance
            let distA = a.placemark.location.map { location.distance(from: $0) } ?? .infinity
            let distB = b.placemark.location.map { location.distance(from: $0) } ?? .infinity
            return distA < distB
        }

        nearbyFields = sorted
    }

    /// Check if a map item is a football/soccer venue
    private func isFootballVenue(item: MKMapItem) -> Bool {
        let name = (item.name ?? "").lowercased()
        let address = (item.placemark.title ?? "").lowercased()
        let combined = name + " " + address

        // Exclude non-football sports venues
        for keyword in Self.excludeKeywords {
            if name.contains(keyword.lowercased()) {
                return false
            }
        }

        // Must contain at least one football keyword
        for keyword in Self.footballKeywords {
            if combined.contains(keyword.lowercased()) {
                return true
            }
        }

        // Check MKMapItem category if available
        if let category = item.pointOfInterestCategory {
            // .stadium covers football stadiums
            if category == .stadium {
                return true
            }
        }

        return false
    }
}
