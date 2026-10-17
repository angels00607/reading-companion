import SwiftUI
import ReadingDomain

/// A review-only surface. The parent must verify the signed-in account and
/// revalidate the preview before passing approval to the upload executor.
struct FirstUploadReviewPanel: View {
    let plan: CoreSyncUploadPreview.Plan
    let destinationEmail: String
    let onApprove: (Set<String>) -> Void

    @State private var acknowledgesPartialScope = false
    @State private var confirmsDestination = false

    private var bookCount: Int { plan.items.filter { $0.recordType == .book }.count }
    private var readingCount: Int { plan.items.filter { $0.recordType == .reading }.count }
    private var approvedIDs: Set<String> {
        Set(plan.items.map { "\($0.recordType.rawValue):\($0.recordID.uuidString)" })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review first cloud upload").font(.title2.bold())
            Text("Destination: \(destinationEmail)").font(.headline)
            Text("\(bookCount) books and \(readingCount) readings prepared.")
            Text("Other library information, including series, journal entries, challenges and settings, is NOT included in this upload.")
                .foregroundStyle(.secondary)
            if !plan.needsReview.isEmpty {
                Text("Upload blocked: \(plan.needsReview.count) items require review.")
                    .foregroundStyle(.red)
                ForEach(plan.needsReview, id: \.self) { reason in
                    Text(reason).font(.caption)
                }
            }
            Toggle("I understand that this is only a partial library upload.", isOn: $acknowledgesPartialScope)
            Toggle("I confirm the destination Google account shown above.", isOn: $confirmsDestination)
            Button("Approve this upload") {
                onApprove(approvedIDs)
            }
            .disabled(!plan.canUpload || plan.items.isEmpty ||
                      !acknowledgesPartialScope || !confirmsDestination ||
                      destinationEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(24)
        .frame(minWidth: 460)
    }
}
