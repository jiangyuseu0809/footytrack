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
                        // Current location
                        currentLocationCard

                        // Manual input
                        manualInputSection

                        // Nearby football fields
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
                await searchNearbyFields()
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
            Text("手动输入")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: 10) {
                TextField("输入球场名称", text: $editText)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textPrimary)
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
    }

    // MARK: - Nearby Fields

    private var nearbyFieldsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("附近球场")
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

    private func searchNearbyFields() async {
        guard let coord = coordinate else { return }
        isSearching = true
        defer { isSearching = false }

        var allItems: [MKMapItem] = []
        let queries = ["足球场", "football field", "soccer field", "体育场"]
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)

        for query in queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 3000,
                longitudinalMeters: 3000
            )
            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                for item in response.mapItems {
                    // Deduplicate by name
                    if let name = item.name, !allItems.contains(where: { $0.name == name }) {
                        allItems.append(item)
                    }
                }
            } catch {
                continue
            }
        }

        // Sort by distance
        nearbyFields = allItems.sorted { a, b in
            let distA = a.placemark.location.map { location.distance(from: $0) } ?? .infinity
            let distB = b.placemark.location.map { location.distance(from: $0) } ?? .infinity
            return distA < distB
        }
    }
}
