import SwiftData
import SwiftUI
import UIKit

// 写真の一覧（SCREENS.md 10）。一覧では thumbnailData だけを読み、jpegData は全画面で読む（CLAUDE.md）。

/// サムネイル1枚。
struct PhotoThumbnail: View {
    let photo: Photo
    var size: CGFloat = 96

    var body: some View {
        Group {
            if let image = UIImage(data: photo.thumbnailData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(.fill.tertiary)
                    .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: 8))
        .overlay(alignment: .topTrailing) {
            if photo.isCover {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .padding(4)
                    .accessibilityLabel(Text("代表写真"))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: photo.caption.isEmpty ? CohortText.date(photo.capturedAt) : photo.caption))
    }
}

/// 写真の格子。タップで全画面表示。
struct PhotoGrid: View {
    let photos: [Photo]
    @State private var viewing: PhotoViewing? = nil

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(photos) { photo in
                Button {
                    viewing = PhotoViewing(photos: photos, startID: photo.id)
                } label: {
                    PhotoThumbnail(photo: photo)
                }
                .buttonStyle(.plain)
            }
        }
        .fullScreenCover(item: $viewing) { viewing in
            PhotoViewer(photos: viewing.photos, startID: viewing.startID)
        }
    }
}

struct PhotoViewing: Identifiable {
    let id = UUID()
    let photos: [Photo]
    let startID: UUID
}

/// 付け先ごとの写真の枠（List の中に置く）。追加の入口と、写真の格子。
struct PhotoSection: View {
    @Environment(\.modelContext) private var modelContext
    let owner: PhotoOwner
    @State private var error: UserFacingError? = nil

    var body: some View {
        let photos = owner.photos
        Section {
            if photos.isEmpty {
                Text("写真はまだありません")
                    .foregroundStyle(.secondary)
            } else {
                PhotoGrid(photos: photos)
                    .padding(.vertical, 4)
            }
            PhotoAdder { processed in add(processed) }
        } header: {
            Text("写真")
        }
        .errorAlert($error)
    }

    private func add(_ processed: [ProcessedPhoto]) {
        for photo in processed {
            PhotoOperations.add(photo, to: owner, in: modelContext)
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            self.error = UserFacingError(error)
        }
    }
}
