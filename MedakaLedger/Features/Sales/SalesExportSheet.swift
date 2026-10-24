import SwiftUI
import UniformTypeIdentifiers

// 販売CSVの書き出し（SCREENS.md 8.1）。開始日と終了日を指定する。第5週でProの限定にする（DECISIONS.md H）。

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct SalesExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let records: [SaleRecord]
    @State private var start: Date
    @State private var end = Date()
    @State private var document = CSVDocument(data: Data())
    @State private var isExporting = false
    @State private var error: UserFacingError?

    init(records: [SaleRecord]) {
        self.records = records
        let calendar = Calendar.current
        _start = State(initialValue: calendar.date(from: calendar.dateComponents([.year], from: Date())) ?? Date())
    }

    private var selected: [SaleRecord] {
        SalesAggregations.filter(records, from: start, to: end, calendar: .current)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("開始日", selection: $start, displayedComponents: .date)
                    DatePicker("終了日", selection: $end, displayedComponents: .date)
                    InfoRow(title: "書き出す件数", value: String(localized: "\(selected.count.formatted())件"))
                } footer: {
                    Text("取消と出品中も含めて、状態の列に書き出します。ExcelやNumbersで開けます。")
                }
            }
            .themedBackground()
            .navigationTitle("販売CSV")
            .navigationBarTitleDisplayMode(.inline)
            .bottomSaveBar("書き出す", isEnabled: !selected.isEmpty && start <= end, identifier: "exportSalesCSVButton") {
                document = CSVDocument(data: CSVExporter.salesCSV(selected, calendar: .current))
                isExporting = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .fileExporter(isPresented: $isExporting, document: document, contentType: .commaSeparatedText, defaultFilename: filename) { result in
                switch result {
                case .success: dismiss()
                case let .failure(failure): error = UserFacingError(failure, title: String(localized: "書き出せませんでした"))
                }
            }
            .errorAlert($error)
        }
    }

    private var filename: String {
        let calendar = Calendar.current
        return "販売台帳_\(CSVExporter.isoDate(start, calendar: calendar))_\(CSVExporter.isoDate(end, calendar: calendar))"
    }
}
