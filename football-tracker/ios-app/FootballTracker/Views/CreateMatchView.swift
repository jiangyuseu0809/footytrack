import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Team Color

enum TeamColor: String, CaseIterable, Identifiable, Codable {
    case red, blue, green, orange, yellow, white

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: return Color(hex: 0xEF4444)
        case .blue: return Color(hex: 0x3B82F6)
        case .green: return Color(hex: 0x22C55E)
        case .orange: return Color(hex: 0xF97316)
        case .yellow: return Color(hex: 0xFACC15)
        case .white: return Color.white
        }
    }

    var label: String {
        switch self {
        case .red: return "红"
        case .blue: return "蓝"
        case .green: return "绿"
        case .orange: return "橙"
        case .yellow: return "黄"
        case .white: return "白"
        }
    }
}

// MARK: - Weekday Rule

enum WeekdayRule: Int, CaseIterable, Identifiable, Codable {
    case monday = 2, tuesday = 3, wednesday = 4, thursday = 5
    case friday = 6, saturday = 7, sunday = 1

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .monday: return "一"
        case .tuesday: return "二"
        case .wednesday: return "三"
        case .thursday: return "四"
        case .friday: return "五"
        case .saturday: return "六"
        case .sunday: return "日"
        }
    }

    var label: String { "周\(shortLabel)" }

    /// Next occurrence of this weekday from today (includes today)
    func nextDate() -> Date {
        let cal = Calendar.current
        let today = Date()
        let todayWeekday = cal.component(.weekday, from: today)
        var diff = rawValue - todayWeekday
        if diff < 0 { diff += 7 }
        return cal.date(byAdding: .day, value: diff, to: today) ?? today
    }
}

// MARK: - Match Template

struct MatchTemplate: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let weekdays: [WeekdayRule]
    let timeHour: Int
    let timeMinute: Int
    let location: String
    let groups: Int
    let players: Int
    let groupColors: [TeamColor]

    var timeText: String {
        String(format: "%02d:%02d", timeHour, timeMinute)
    }

    var weekdayText: String {
        if weekdays.isEmpty { return "未设置" }
        return weekdays.map(\.label).joined(separator: "、")
    }

    var summaryText: String {
        "\(weekdayText) \(timeText) · \(groups)v\(players)"
    }
}

// MARK: - Codable Color (for custom colors persistence)

struct CodableColor: Codable, Equatable, Identifiable {
    let hex: String
    var id: String { hex }

    var color: Color {
        guard let val = UInt(hex, radix: 16) else { return .gray }
        return Color(hex: val)
    }

    init(hex: String) {
        self.hex = hex
    }

    init(from color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.hex = String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Create Match View

struct CreateMatchView: View {
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var selectedWeekdays: Set<WeekdayRule> = []
    @State private var matchTime: Date = {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 20
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }()
    @State private var location = ""
    @State private var groupCount = 2
    @State private var playersPerGroup = 11
    @State private var groupColors: [TeamColor] = []
    @State private var isApplyingTemplate = false

    // Custom color state
    @State private var customColor: Color = Color(hex: 0xEC4899)
    @State private var showCustomColorSheet = false
    @State private var savedCustomColors: [CodableColor] = []

    private static let customColorsKey = "custom_team_colors_v2"

    // Template state
    @State private var selectedTemplateId: String?
    @State private var showSaveTemplateSheet = false
    @State private var isEditingTemplates = false
    @State private var editingTemplate: MatchTemplate?
    @State private var templateName = ""
    @State private var savedTemplates: [MatchTemplate] = []

    private static let templatesKey = "match_templates"

    private func loadTemplates() {
        guard let data = UserDefaults.standard.data(forKey: Self.templatesKey),
              let decoded = try? JSONDecoder().decode([MatchTemplate].self, from: data) else { return }
        savedTemplates = decoded
    }

    private func persistTemplates() {
        guard let data = try? JSONEncoder().encode(savedTemplates) else { return }
        UserDefaults.standard.set(data, forKey: Self.templatesKey)
    }

    // Template sheet editing state (independent from main form)
    @State private var tplWeekdays: Set<WeekdayRule> = []
    @State private var tplTime: Date = Date()
    @State private var tplLocation = ""
    @State private var tplGroups = 2
    @State private var tplPlayers = 11
    @State private var tplGroupColors: [TeamColor] = []

    // Share state
    @State private var showShareSheet = false
    @State private var shareLink = ""
    @State private var linkCopied = false
    @State private var isCreating = false

    private var totalPlayers: Int { groupCount * playersPerGroup }

    private var isFormValid: Bool {
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selectedWeekdays.isEmpty
    }

    /// Nearest upcoming match date based on selected weekdays
    private var nearestMatchDateText: String? {
        guard !selectedWeekdays.isEmpty else { return nil }
        let cal = Calendar.current
        let hour = cal.component(.hour, from: matchTime)
        let minute = cal.component(.minute, from: matchTime)

        let nearest = sortedWeekdays
            .map { $0.nextDate() }
            .min { $0 < $1 }

        guard let date = nearest else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return "\(formatter.string(from: date)) \(String(format: "%02d:%02d", hour, minute))"
    }

    private var sortedWeekdays: [WeekdayRule] {
        selectedWeekdays.sorted { a, b in
            let order: [WeekdayRule] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
            return (order.firstIndex(of: a) ?? 0) < (order.firstIndex(of: b) ?? 0)
        }
    }

    private var tplSortedWeekdays: [WeekdayRule] {
        tplWeekdays.sorted { a, b in
            let order: [WeekdayRule] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
            return (order.firstIndex(of: a) ?? 0) < (order.firstIndex(of: b) ?? 0)
        }
    }

    private func initTemplateSheetState(from template: MatchTemplate?) {
        if let tpl = template {
            templateName = tpl.name
            tplWeekdays = Set(tpl.weekdays)
            tplLocation = tpl.location
            tplGroups = tpl.groups
            tplPlayers = tpl.players
            tplGroupColors = tpl.groupColors
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour = tpl.timeHour
            comps.minute = tpl.timeMinute
            tplTime = Calendar.current.date(from: comps) ?? Date()
        } else {
            templateName = ""
            tplWeekdays = selectedWeekdays
            tplTime = matchTime
            tplLocation = location
            tplGroups = groupCount
            tplPlayers = playersPerGroup
            tplGroupColors = groupColors
        }
    }

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    templateSection
                    matchTimeSection
                    locationSection
                    groupSettingsSection
                    summaryCard
                    actionButtons
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }

            if isCreating {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView().tint(AppColors.neonBlue)
            }
        }
        .navigationTitle("发起比赛")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSaveTemplateSheet) {
            saveTemplateSheet
        }
        .sheet(isPresented: $showShareSheet) {
            shareResultSheet
        }
        .onChange(of: groupCount) { _, newValue in
            if groupColors.count > newValue {
                groupColors = Array(groupColors.prefix(newValue))
            }
        }
        .onChange(of: tplGroups) { _, newValue in
            if tplGroupColors.count > newValue {
                tplGroupColors = Array(tplGroupColors.prefix(newValue))
            }
        }
        .onAppear {
            loadTemplates()
            loadCustomColors()
        }
        .sheet(isPresented: $showCustomColorSheet) {
            customColorSheet
        }
    }

    // MARK: - Template Section (Top)

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("快速模板")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                if !savedTemplates.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isEditingTemplates.toggle()
                        }
                    } label: {
                        Text(isEditingTemplates ? "完成" : "编辑")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.neonBlue)
                    }
                }
            }

            if savedTemplates.isEmpty {
                // Empty: show create entry
                Button {
                    editingTemplate = nil
                    initTemplateSheetState(from: nil)
                    showSaveTemplateSheet = true
                } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.neonBlue.opacity(0.15))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(AppColors.neonBlue)
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text("创建第一个模板")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.textPrimary)
                            Text("保存常用的比赛设置，下次一键开赛")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(14)
                    .background(AppColors.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.neonBlue.opacity(0.2), lineWidth: 1)
                    )
                }
            } else {
                // Has templates: horizontal scroll with + card at end
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(savedTemplates) { template in
                            templateCard(template)
                        }

                        // Add new template card
                        Button {
                            editingTemplate = nil
                            initTemplateSheetState(from: nil)
                            showSaveTemplateSheet = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppColors.neonBlue)
                                Text("新建模板")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .frame(width: 160)
                            .frame(maxHeight: .infinity)
                            .background(AppColors.cardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AppColors.neonBlue.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                }
            }
        }
    }

    private func templateCard(_ template: MatchTemplate) -> some View {
        let isSelected = selectedTemplateId == template.id

        return Button {
            if isEditingTemplates {
                editingTemplate = template
                initTemplateSheetState(from: template)
                showSaveTemplateSheet = true
            } else {
                if selectedTemplateId == template.id {
                    selectedTemplateId = nil
                    resetForm()
                } else {
                    applyTemplate(template)
                }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(template.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(isSelected && !isEditingTemplates ? .white : AppColors.textPrimary)
                            .lineLimit(1)

                        if isSelected && !isEditingTemplates {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text("\(template.weekdayText) \(template.timeText)")
                                .font(.caption2)
                        }
                        .foregroundColor(isSelected && !isEditingTemplates ? .white.opacity(0.85) : AppColors.textSecondary)

                        if !template.location.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 10))
                                Text(template.location)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .foregroundColor(isSelected && !isEditingTemplates ? .white.opacity(0.85) : AppColors.textSecondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "person.2")
                                .font(.system(size: 10))
                            Text("\(template.groups)队 × \(template.players)人")
                                .font(.caption2)
                        }
                        .foregroundColor(isSelected && !isEditingTemplates ? .white.opacity(0.85) : AppColors.textSecondary)
                    }
                }
                .padding(12)
                .frame(width: 160, alignment: .leading)
                .background(
                    isSelected && !isEditingTemplates
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    : AnyShapeStyle(AppColors.cardBg)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isEditingTemplates
                            ? AppColors.calorieOrange.opacity(0.4)
                            : isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.06),
                            lineWidth: isEditingTemplates ? 1.5 : 1
                        )
                )

                // Edit mode: delete badge
                if isEditingTemplates {
                    Button {
                        deleteTemplate(template)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.heartRed)
                            .background(Circle().fill(AppColors.darkBg).padding(2))
                    }
                    .offset(x: 6, y: -6)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isEditingTemplates)
        }
    }

    // MARK: - Match Time

    private var matchTimeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("比赛时间")
                .font(.title3.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)

            VStack(spacing: 0) {
                // Weekday selector
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        iconSquare(
                            icon: "calendar",
                            colors: [Color(hex: 0x3B82F6), Color(hex: 0x06B6D4)]
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("比赛日")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                            if selectedWeekdays.isEmpty {
                                Text("选择比赛日")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                            } else {
                                Text("每\(sortedWeekdays.map(\.label).joined(separator: "、"))")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }
                        Spacer()
                    }

                    // Weekday pills
                    HStack(spacing: 6) {
                        ForEach(WeekdayRule.allCases) { day in
                            let isOn = selectedWeekdays.contains(day)
                            Button {
                                if isOn {
                                    selectedWeekdays.remove(day)
                                } else {
                                    selectedWeekdays.insert(day)
                                }
                                if !isApplyingTemplate { selectedTemplateId = nil }
                            } label: {
                                Text(day.shortLabel)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(isOn ? .white : AppColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(
                                        isOn
                                        ? AnyShapeStyle(LinearGradient(
                                            colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ))
                                        : AnyShapeStyle(AppColors.cardBgLight)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                isOn ? Color.white.opacity(0.15) : Color.white.opacity(0.06),
                                                lineWidth: 1
                                            )
                                    )
                            }
                        }
                    }
                }
                .padding(14)

                Divider().overlay(AppColors.dividerColor)

                // Time picker
                HStack(spacing: 12) {
                    iconSquare(
                        icon: "clock.fill",
                        colors: [Color(hex: 0xA855F7), Color(hex: 0xEC4899)]
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("开场时间")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)

                        DatePicker("", selection: $matchTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(AppColors.neonBlue)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                            .onChange(of: matchTime) { _, _ in
                                if !isApplyingTemplate { selectedTemplateId = nil }
                            }
                    }

                    Spacer()
                }
                .padding(14)
            }
            .background(AppColors.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Location

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("比赛地点")
                .font(.title3.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)

            HStack(spacing: 12) {
                iconSquare(
                    icon: "mappin.and.ellipse",
                    colors: [Color(hex: 0x22C55E), Color(hex: 0x10B981)]
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("场地")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    TextField("", text: $location, prompt: Text("输入球场名称").foregroundColor(AppColors.textSecondary))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: location) { _, _ in
                            if !isApplyingTemplate { selectedTemplateId = nil }
                        }
                }
            }
            .padding(14)
            .background(AppColors.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Group Settings

    private var groupSettingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分组设置")
                .font(.title3.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)

            VStack(spacing: 0) {
                // Number of groups
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        iconSquare(
                            icon: "person.2.fill",
                            colors: [Color(hex: 0xF97316), Color(hex: 0xEF4444)]
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("队伍数量")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Text("\(groupCount) 队")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                        }

                        Spacer()
                    }

                    stepperRow(
                        value: $groupCount,
                        range: 2...6,
                        maxForProgress: 6,
                        gradientColors: [Color(hex: 0xF97316), Color(hex: 0xEF4444)]
                    )
                }
                .padding(14)

                Divider().overlay(AppColors.dividerColor)

                // Players per group
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        iconSquare(
                            icon: "person.3.fill",
                            colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)]
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("每队人数")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Text("\(playersPerGroup) 人")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                        }

                        Spacer()
                    }

                    stepperRow(
                        value: $playersPerGroup,
                        range: 3...15,
                        maxForProgress: 15,
                        gradientColors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)]
                    )
                }
                .padding(14)

                Divider().overlay(AppColors.dividerColor)

                // Team colors (optional)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        iconSquare(
                            icon: "tshirt.fill",
                            colors: [Color(hex: 0xEC4899), Color(hex: 0xF43F5E)]
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("队服颜色")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Text("可选")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textSecondary.opacity(0.6))
                        }

                        Spacer()

                        if !groupColors.isEmpty {
                            Button {
                                groupColors = []
                                if !isApplyingTemplate { selectedTemplateId = nil }
                            } label: {
                                Text("清除")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }

                    colorPickerGrid(selection: $groupColors, max: groupCount)
                }
                .padding(14)
            }
            .background(AppColors.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("比赛概要")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    HStack(spacing: 4) {
                        Text("共需")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                        Text("\(totalPlayers)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppColors.neonBlue)
                        Text("人")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }

                Spacer()

                Text("\(groupCount)队 × \(playersPerGroup)人")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(hex: 0x60A5FA))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }

            if !selectedWeekdays.isEmpty || !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Divider().overlay(AppColors.dividerColor.opacity(0.5))

                HStack(spacing: 16) {
                    if !selectedWeekdays.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(nearestMatchDateText ?? "")
                                .font(.caption2)
                        }
                        .foregroundColor(AppColors.neonBlue)
                    }

                    let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedLocation.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.caption2)
                            Text(trimmedLocation)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()
                }
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x1E3A5F).opacity(0.5), Color(hex: 0x2D1B69).opacity(0.3)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: 0x3B82F6).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private var actionButtons: some View {
        Button {
            createMatch()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                Text("创建并分享比赛")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isFormValid
                ? AnyShapeStyle(LinearGradient(
                    colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                : AnyShapeStyle(Color.gray.opacity(0.4))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isFormValid || isCreating)
    }

    // MARK: - Save/Edit Template Sheet

    private var isEditMode: Bool { editingTemplate != nil }

    private var saveTemplateSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        // Template name
                        VStack(alignment: .leading, spacing: 10) {
                            Text("模板名称 *")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.textPrimary)

                            TextField("", text: $templateName, prompt: Text("例如: 周三野球").foregroundColor(AppColors.textSecondary))
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(AppColors.cardBgLight)
                                .cornerRadius(10)
                        }
                        .padding(16)
                        .background(AppColors.cardBg)
                        .cornerRadius(14)

                        // Weekday selector
                        VStack(alignment: .leading, spacing: 10) {
                            Text("比赛日")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.textPrimary)

                            if tplWeekdays.isEmpty {
                                Text("选择比赛日")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            } else {
                                Text("每\(tplSortedWeekdays.map(\.label).joined(separator: "、"))")
                                    .font(.caption)
                                    .foregroundColor(AppColors.neonBlue)
                            }

                            HStack(spacing: 6) {
                                ForEach(WeekdayRule.allCases) { day in
                                    let isOn = tplWeekdays.contains(day)
                                    Button {
                                        if isOn { tplWeekdays.remove(day) }
                                        else { tplWeekdays.insert(day) }
                                    } label: {
                                        Text(day.shortLabel)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(isOn ? .white : AppColors.textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 36)
                                            .background(
                                                isOn
                                                ? AnyShapeStyle(LinearGradient(
                                                    colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ))
                                                : AnyShapeStyle(AppColors.cardBgLight)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(
                                                        isOn ? Color.white.opacity(0.15) : Color.white.opacity(0.06),
                                                        lineWidth: 1
                                                    )
                                            )
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(AppColors.cardBg)
                        .cornerRadius(14)

                        // Time picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("开场时间")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.textPrimary)

                            HStack(spacing: 12) {
                                iconSquare(
                                    icon: "clock.fill",
                                    colors: [Color(hex: 0xA855F7), Color(hex: 0xEC4899)]
                                )
                                DatePicker("", selection: $tplTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .tint(AppColors.neonBlue)
                                    .environment(\.locale, Locale(identifier: "zh_CN"))
                                Spacer()
                            }
                        }
                        .padding(16)
                        .background(AppColors.cardBg)
                        .cornerRadius(14)

                        // Location
                        VStack(alignment: .leading, spacing: 10) {
                            Text("比赛地点")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.textPrimary)

                            HStack(spacing: 12) {
                                iconSquare(
                                    icon: "mappin.and.ellipse",
                                    colors: [Color(hex: 0x22C55E), Color(hex: 0x10B981)]
                                )
                                TextField("", text: $tplLocation, prompt: Text("输入球场名称").foregroundColor(AppColors.textSecondary))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                        }
                        .padding(16)
                        .background(AppColors.cardBg)
                        .cornerRadius(14)

                        // Group settings
                        VStack(alignment: .leading, spacing: 12) {
                            Text("分组设置")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.textPrimary)

                            HStack(spacing: 12) {
                                iconSquare(
                                    icon: "person.2.fill",
                                    colors: [Color(hex: 0xF97316), Color(hex: 0xEF4444)]
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("队伍数量")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                    Text("\(tplGroups) 队")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppColors.textPrimary)
                                }
                                Spacer()
                            }
                            stepperRow(value: $tplGroups, range: 2...6, maxForProgress: 6, gradientColors: [Color(hex: 0xF97316), Color(hex: 0xEF4444)])

                            Divider().overlay(AppColors.dividerColor)

                            HStack(spacing: 12) {
                                iconSquare(
                                    icon: "person.3.fill",
                                    colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)]
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("每队人数")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                    Text("\(tplPlayers) 人")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppColors.textPrimary)
                                }
                                Spacer()
                            }
                            stepperRow(value: $tplPlayers, range: 3...15, maxForProgress: 15, gradientColors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)])

                            Divider().overlay(AppColors.dividerColor)

                            // Team colors (optional)
                            HStack(spacing: 12) {
                                iconSquare(
                                    icon: "tshirt.fill",
                                    colors: [Color(hex: 0xEC4899), Color(hex: 0xF43F5E)]
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("队服颜色")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                    Text("可选")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                                }
                                Spacer()
                                if !tplGroupColors.isEmpty {
                                    Button {
                                        tplGroupColors = []
                                    } label: {
                                        Text("清除")
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                            }
                            colorPickerGrid(selection: $tplGroupColors, max: tplGroups)
                        }
                        .padding(16)
                        .background(AppColors.cardBg)
                        .cornerRadius(14)

                        // Save / Update button
                        Button {
                            saveTemplate()
                        } label: {
                            Text(isEditMode ? "更新模板" : "保存模板")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? AnyShapeStyle(Color.gray.opacity(0.4))
                                    : AnyShapeStyle(LinearGradient(
                                        colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                )
                                .cornerRadius(12)
                        }
                        .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        // Delete button (edit mode only)
                        if isEditMode {
                            Button {
                                if let tpl = editingTemplate {
                                    deleteTemplate(tpl)
                                }
                                templateName = ""
                                editingTemplate = nil
                                showSaveTemplateSheet = false
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                    Text("删除此模板")
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(AppColors.heartRed)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColors.heartRed.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.heartRed.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(isEditMode ? "编辑模板" : "保存模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        templateName = ""
                        editingTemplate = nil
                        showSaveTemplateSheet = false
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Share Result Sheet

    private var shareResultSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBg.ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer().frame(height: 10)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x22C55E), Color(hex: 0x10B981)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        )

                    Text("比赛创建成功！")
                        .font(.title3.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)

                    Text("将链接分享给球友即可报名")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)

                    HStack {
                        Text(shareLink)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)

                        Spacer()

                        Button {
                            copyLink()
                        } label: {
                            Image(systemName: linkCopied ? "checkmark" : "doc.on.doc")
                                .font(.subheadline)
                                .foregroundColor(linkCopied ? Color(hex: 0x22C55E) : AppColors.textSecondary)
                                .padding(8)
                                .background(linkCopied ? Color(hex: 0x22C55E).opacity(0.15) : AppColors.cardBgLight)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(14)
                    .background(AppColors.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(spacing: 12) {
                        Button {
                            shareToWeChat()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "message.fill")
                                Text("分享到微信")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: 0x22C55E), Color(hex: 0x10B981)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                            showShareSheet = false
                            dismiss()
                        } label: {
                            Text("完成")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(AppColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColors.cardBg)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Spacer()
                }
                .padding(16)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showShareSheet = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
    }

    // MARK: - Helpers

    private func colorPickerGrid(selection: Binding<[TeamColor]>, max: Int) -> some View {
        HStack(spacing: 10) {
            ForEach(TeamColor.allCases) { tc in
                colorCircle(tc: tc, selection: selection, max: max)
            }

            // Saved custom colors as extra circles
            ForEach(savedCustomColors) { cc in
                let matchingTC = TeamColor.allCases.first { $0.color.description == cc.color.description }
                if matchingTC == nil {
                    customColorCircle(cc: cc, selection: selection)
                }
            }

            // Add custom color button
            Button {
                showCustomColorSheet = true
            } label: {
                ZStack {
                    Circle()
                        .fill(AppColors.cardBgLight)
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }

            Spacer()
        }
    }

    private func colorCircle(tc: TeamColor, selection: Binding<[TeamColor]>, max: Int) -> some View {
        let index = selection.wrappedValue.firstIndex(of: tc)
        let isOn = index != nil
        let position = index.map { selection.wrappedValue.distance(from: selection.wrappedValue.startIndex, to: $0) + 1 }

        return Button {
            if isOn {
                selection.wrappedValue.removeAll { $0 == tc }
            } else if selection.wrappedValue.count < max {
                selection.wrappedValue.append(tc)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(tc.color)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(
                                tc == .white ? Color.gray.opacity(0.4) : Color.clear,
                                lineWidth: 1
                            )
                    )

                if isOn, let pos = position {
                    Text("\(pos)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(tc == .white || tc == .yellow ? .black : .white)
                }
            }
            .overlay(
                Circle()
                    .stroke(isOn ? tc.color.opacity(0.6) : Color.clear, lineWidth: 2)
                    .padding(-3)
            )
        }
    }

    private func customColorCircle(cc: CodableColor, selection: Binding<[TeamColor]>) -> some View {
        // Custom colors are shown but not selectable as TeamColor
        // They serve as visual reference; long-press to remove
        Circle()
            .fill(cc.color)
            .frame(width: 32, height: 32)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .contextMenu {
                Button(role: .destructive) {
                    savedCustomColors.removeAll { $0.id == cc.id }
                    persistCustomColors()
                } label: {
                    Label("移除", systemImage: "trash")
                }
            }
    }

    // Custom color sheet
    private var customColorSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBg.ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer().frame(height: 10)

                    // Preview
                    Circle()
                        .fill(customColor)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        )

                    Text("选择自定义颜色")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    // Color picker
                    ColorPicker("选择颜色", selection: $customColor, supportsOpacity: false)
                        .labelsHidden()
                        .scaleEffect(1.5)
                        .frame(width: 50, height: 50)

                    // Add button
                    Button {
                        addCustomColor()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("添加此颜色")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)

                    // Existing custom colors
                    if !savedCustomColors.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("已添加的自定义颜色")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppColors.textSecondary)

                            HStack(spacing: 10) {
                                ForEach(savedCustomColors) { cc in
                                    Circle()
                                        .fill(cc.color)
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                savedCustomColors.removeAll { $0.id == cc.id }
                                                persistCustomColors()
                                            } label: {
                                                Label("移除", systemImage: "trash")
                                            }
                                        }
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer()
                }
            }
            .navigationTitle("自定义颜色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        showCustomColorSheet = false
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func addCustomColor() {
        let cc = CodableColor(from: customColor)
        // Don't add duplicates
        if !savedCustomColors.contains(where: { $0.hex == cc.hex }) {
            savedCustomColors.append(cc)
            persistCustomColors()
        }
        showCustomColorSheet = false
    }

    private func persistCustomColors() {
        guard let data = try? JSONEncoder().encode(savedCustomColors) else { return }
        UserDefaults.standard.set(data, forKey: Self.customColorsKey)
    }

    private func loadCustomColors() {
        guard let data = UserDefaults.standard.data(forKey: Self.customColorsKey),
              let decoded = try? JSONDecoder().decode([CodableColor].self, from: data) else { return }
        savedCustomColors = decoded
    }

    private func iconSquare(icon: String, colors: [Color]) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            )
    }

    private func stepperRow(value: Binding<Int>, range: ClosedRange<Int>, maxForProgress: Int, gradientColors: [Color]) -> some View {
        HStack(spacing: 12) {
            Button {
                if value.wrappedValue > range.lowerBound {
                    value.wrappedValue -= 1
                    if !isApplyingTemplate { selectedTemplateId = nil }
                }
            } label: {
                Text("−")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(AppColors.cardBgLight)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.cardBgLight)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(value.wrappedValue) / CGFloat(maxForProgress), height: 6)
                        .animation(.easeInOut(duration: 0.2), value: value.wrappedValue)
                }
            }
            .frame(height: 6)

            Button {
                if value.wrappedValue < range.upperBound {
                    value.wrappedValue += 1
                    if !isApplyingTemplate { selectedTemplateId = nil }
                }
            } label: {
                Text("+")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(AppColors.cardBgLight)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
        }
    }

    private func resetForm() {
        isApplyingTemplate = true
        selectedWeekdays = []
        location = ""
        groupCount = 2
        playersPerGroup = 11
        groupColors = []
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 20
        comps.minute = 0
        if let date = Calendar.current.date(from: comps) {
            matchTime = date
        }
        DispatchQueue.main.async {
            isApplyingTemplate = false
        }
    }

    private func applyTemplate(_ template: MatchTemplate) {
        isApplyingTemplate = true
        selectedWeekdays = Set(template.weekdays)
        location = template.location
        groupCount = template.groups
        playersPerGroup = template.players
        groupColors = template.groupColors

        // Set time from template
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = template.timeHour
        comps.minute = template.timeMinute
        if let date = Calendar.current.date(from: comps) {
            matchTime = date
        }

        selectedTemplateId = template.id
        DispatchQueue.main.async {
            isApplyingTemplate = false
        }
    }

    private func deleteTemplate(_ template: MatchTemplate) {
        savedTemplates.removeAll { $0.id == template.id }
        if selectedTemplateId == template.id {
            selectedTemplateId = nil
        }
        if savedTemplates.isEmpty {
            isEditingTemplates = false
        }
        persistTemplates()
    }

    private func saveTemplate() {
        let trimmed = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let cal = Calendar.current
        let hour = cal.component(.hour, from: tplTime)
        let minute = cal.component(.minute, from: tplTime)

        let newTemplate = MatchTemplate(
            id: editingTemplate?.id ?? UUID().uuidString,
            name: trimmed,
            weekdays: tplSortedWeekdays,
            timeHour: hour,
            timeMinute: minute,
            location: tplLocation.trimmingCharacters(in: .whitespacesAndNewlines),
            groups: tplGroups,
            players: tplPlayers,
            groupColors: tplGroupColors
        )

        if let existing = editingTemplate,
           let index = savedTemplates.firstIndex(where: { $0.id == existing.id }) {
            savedTemplates[index] = newTemplate
        } else {
            savedTemplates.append(newTemplate)
        }

        selectedTemplateId = newTemplate.id
        applyTemplate(newTemplate)
        templateName = ""
        editingTemplate = nil
        showSaveTemplateSheet = false
        isEditingTemplates = false
        persistTemplates()
    }

    private func createMatch() {
        guard isFormValid else { return }
        isCreating = true

        // TODO: Call API to create match — POST /api/matches
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let mockId = UUID().uuidString.prefix(8).lowercased()
            shareLink = "https://footytrack.cn/m/\(mockId)"
            isCreating = false
            showShareSheet = true
        }
    }

    private func copyLink() {
        UIPasteboard.general.string = shareLink
        linkCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            linkCopied = false
        }
    }

    private func shareToWeChat() {
        // TODO: Integrate WeChat Open SDK
    }
}
