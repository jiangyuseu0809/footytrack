import SwiftUI

/// Main tracking view for watchOS - multi-state game flow matching reference UI.
struct WatchTrackingView: View {
    @ObservedObject var manager: TrackingManager

    var body: some View {
        switch manager.gameState {
        case .idle:
            startScreen
        case .countdown(let count):
            countdownScreen(count: count)
        case .playing:
            playingScreen
        case .paused:
            pausedScreen
        case .halftime:
            halftimeScreen
        case .finished:
            finishedScreen
        }
    }

    // MARK: - Start Screen

    private var startScreen: some View {
        VStack {
            Spacer()
            Button(action: { manager.startGame() }) {
                VStack(spacing: 4) {
                    Text("开始")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("START")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(width: 120, height: 120)
                .background(
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.green.opacity(0.8), Color.green],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .shadow(color: .green.opacity(0.5), radius: 16, y: 6)
                )
            }
            .buttonStyle(.plain)

            Text("点击开始比赛")
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - Countdown Screen

    private func countdownScreen(count: Int) -> some View {
        VStack {
            Spacer()
            Text("\(count)")
                .font(.system(size: 110, weight: .bold))
                .foregroundColor(count == 3 ? .red : count == 2 ? .yellow : .green)
                .shadow(color: (count == 3 ? Color.red : count == 2 ? Color.yellow : Color.green).opacity(0.5), radius: 20, y: 4)
            Spacer()
        }
    }

    // MARK: - Playing Screen

    private var playingScreen: some View {
        ScrollView {
            VStack(spacing: 6) {
                // Half indicator + timer
                Text("第 \(manager.currentHalf) 节")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)

                Text(manager.formatTime(manager.elapsedSeconds))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                // Live stats row
                HStack(spacing: 12) {
                    liveStatPill(icon: "❤️", value: "\(manager.currentHeartRate)", color: .red)
                    liveStatPill(icon: "⚡", value: String(format: "%.1f", manager.currentSpeedMs * 3.6), color: .orange)
                }
                .padding(.bottom, 2)

                // Goals counter
                counterCard(
                    label: "进球",
                    value: manager.goals,
                    bgColor: Color.green.opacity(0.15),
                    accentColor: .green,
                    onIncrement: { manager.incrementGoals() },
                    onDecrement: { manager.decrementGoals() }
                )

                // Assists counter
                counterCard(
                    label: "助攻",
                    value: manager.assists,
                    bgColor: Color.blue.opacity(0.15),
                    accentColor: .blue,
                    onIncrement: { manager.incrementAssists() },
                    onDecrement: { manager.decrementAssists() }
                )

                // Actions
                Button(action: { manager.endHalf() }) {
                    Text("结束本节")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Paused Screen

    private var pausedScreen: some View {
        VStack(spacing: 12) {
            Spacer()

            // Pause icon
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 56, height: 56)
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray)
                        .frame(width: 4, height: 20)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray)
                        .frame(width: 4, height: 20)
                }
            }

            Text("已暂停")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text(manager.formatTime(manager.elapsedSeconds))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Spacer()

            Button(action: { manager.resumeGame() }) {
                Text("继续比赛")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            Button(action: { manager.endHalf() }) {
                Text("结束本节")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Halftime Screen

    private var halftimeScreen: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.orange)
                }

                Text("节间休息")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text("第 \(manager.currentHalf) 节已结束")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                // Stats summary for this half
                HStack(spacing: 8) {
                    halfStatCard(value: "\(manager.goals)", label: "进球")
                    halfStatCard(value: "\(manager.assists)", label: "助攻")
                }
                .padding(.vertical, 4)

                // Next half with swap sides option
                Button(action: { manager.startNextHalf(swapSides: false) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13))
                        Text("下一节")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button(action: { manager.startNextHalf(swapSides: true) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 13))
                        Text("交换场地 & 下一节")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button(action: { manager.endMatchFromHalftime() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13))
                        Text("结束比赛")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Finished Screen

    private var finishedScreen: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Trophy
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.yellow.opacity(0.6), Color.orange],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 56, height: 56)
                        .shadow(color: .yellow.opacity(0.4), radius: 12, y: 4)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }

                Text("比赛结束")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("用时 \(manager.formatTime(manager.summaryDurationSeconds))")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                // Final stats
                VStack(spacing: 6) {
                    finishedStatRow(label: "进球", value: "\(manager.summaryGoals)", bgColor: Color.green.opacity(0.15))
                    finishedStatRow(label: "助攻", value: "\(manager.summaryAssists)", bgColor: Color.blue.opacity(0.15))
                    finishedStatRow(label: "距离", value: String(format: "%.1fkm", manager.summaryDistanceMeters / 1000), bgColor: Color.purple.opacity(0.15))
                    finishedStatRow(label: "卡路里", value: "\(Int(manager.summaryCalories))", bgColor: Color.red.opacity(0.15))
                }
                .padding(.vertical, 4)

                Text("数据已同步到手机")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)

                Button(action: { manager.startNewGame() }) {
                    Text("开始新比赛")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Components

    private func liveStatPill(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(icon).font(.system(size: 10))
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .cornerRadius(10)
    }

    private func counterCard(label: String, value: Int, bgColor: Color, accentColor: Color,
                             onIncrement: @escaping () -> Void, onDecrement: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)

            HStack {
                Button(action: onDecrement) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(value == 0 ? Color.gray.opacity(0.2) : Color.red.opacity(0.8))
                        .foregroundColor(value == 0 ? .gray : .white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(value == 0)

                Spacer()
                Text("\(value)")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()

                Button(action: onIncrement) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(accentColor)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(bgColor)
        .cornerRadius(14)
    }

    private func halfStatCard(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }

    private func finishedStatRow(label: String, value: String, bgColor: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(bgColor)
        .cornerRadius(12)
    }
}
