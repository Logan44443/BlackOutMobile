import Foundation
import SwiftUI

@MainActor
class AdminSettingsViewModel: ObservableObject {
    let groupId: UUID

    @Published var cardsPerPeriod: Int = 1
    @Published var periodType: PeriodType = .month
    @Published var periodStart = Date()
    @Published var periodEnd = Date()
    @Published var voteDurationHours: Int = 12
    @Published var showResetConfirmation = false
    @Published var saveSuccessful = false
    @Published var errorMessage: String?

    private let store = DataStore.shared

    init(groupId: UUID) {
        self.groupId = groupId
        loadSettings()
    }

    func loadSettings() {
        guard let group = store.group(for: groupId) else { return }
        cardsPerPeriod = group.cardsPerPeriod
        periodType = group.periodType
        periodStart = group.periodStart ?? Date()
        periodEnd = group.periodEnd ?? Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        voteDurationHours = group.voteDurationHours
    }

    func saveSettings() {
        Task { [weak self] in
            guard let self else { return }
            await self.store.updateGroupSettings(
                groupId: self.groupId,
                cardsPerPeriod: self.cardsPerPeriod,
                periodType: self.periodType,
                periodStart: self.periodStart,
                periodEnd: self.periodEnd
            )
            self.saveSuccessful = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.saveSuccessful = false
            }
        }
    }

    func resetPeriod() {
        Task { [weak self] in
            guard let self else { return }
            await self.store.resetPeriod(groupId: self.groupId)
            self.showResetConfirmation = false
        }
    }
}
