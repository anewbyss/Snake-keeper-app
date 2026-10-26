import Foundation

/// One spreadsheet cell.
enum Cell {
    case text(String)
    case number(Double)
    case date(Date)
    case empty
}

struct Worksheet {
    var name: String
    var columns: [String]
    var rows: [[Cell]]
}

/// Writes minimal .xlsx workbooks (opens in Excel, Google Sheets, Numbers) and CSV.
enum XLSXWriter {
    static func data(for sheets: [Worksheet]) -> Data {
        var zip = ZipWriter()
        zip.add("[Content_Types].xml", contentTypes(sheetCount: sheets.count))
        zip.add("_rels/.rels", rootRelationships)
        zip.add("xl/workbook.xml", workbook(sheets))
        zip.add("xl/_rels/workbook.xml.rels", workbookRelationships(sheetCount: sheets.count))
        zip.add("xl/styles.xml", styles)
        for (index, sheet) in sheets.enumerated() {
            zip.add("xl/worksheets/sheet\(index + 1).xml", worksheet(sheet))
        }
        return zip.finish()
    }

    static func csv(for sheet: Worksheet) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = .current

        func field(_ cell: Cell) -> String {
            let text: String
            switch cell {
            case .text(let value): text = value
            case .number(let value): text = numberString(value)
            case .date(let value): text = formatter.string(from: value)
            case .empty: text = ""
            }
            guard text.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return text }
            return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }

        let lines = [sheet.columns.map { field(.text($0)) }] + sheet.rows.map { $0.map(field) }
        return lines.map { $0.joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    // MARK: - Parts

    private static let header = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"# + "\n"
    private static let mainNS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    private static let relNS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    private static let packageRelNS = "http://schemas.openxmlformats.org/package/2006/relationships"

    private static func contentTypes(sheetCount: Int) -> String {
        let sheets = (1...max(sheetCount, 1)).map {
            #"<Override PartName="/xl/worksheets/sheet\#($0).xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>"#
        }.joined()
        return header
            + #"<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">"#
            + #"<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>"#
            + #"<Default Extension="xml" ContentType="application/xml"/>"#
            + #"<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>"#
            + #"<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>"#
            + sheets
            + "</Types>"
    }

    private static let rootRelationships = header
        + #"<Relationships xmlns="\#(packageRelNS)">"#
        + #"<Relationship Id="rId1" Type="\#(relNS)/officeDocument" Target="xl/workbook.xml"/>"#
        + "</Relationships>"

    private static func workbook(_ sheets: [Worksheet]) -> String {
        let entries = sheets.enumerated().map { index, sheet in
            #"<sheet name="\#(escape(sheetName(sheet.name)))" sheetId="\#(index + 1)" r:id="rId\#(index + 1)"/>"#
        }.joined()
        return header
            + #"<workbook xmlns="\#(mainNS)" xmlns:r="\#(relNS)"><sheets>"#
            + entries
            + "</sheets></workbook>"
    }

    private static func workbookRelationships(sheetCount: Int) -> String {
        let sheets = (0..<sheetCount).map {
            #"<Relationship Id="rId\#($0 + 1)" Type="\#(relNS)/worksheet" Target="worksheets/sheet\#($0 + 1).xml"/>"#
        }.joined()
        return header
            + #"<Relationships xmlns="\#(packageRelNS)">"#
            + sheets
            + #"<Relationship Id="rId\#(sheetCount + 1)" Type="\#(relNS)/styles" Target="styles.xml"/>"#
            + "</Relationships>"
    }

    /// Style 0: normal, 1: bold header, 2: date.
    private static let styles = header
        + #"<styleSheet xmlns="\#(mainNS)">"#
        + #"<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>"#
        + #"<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>"#
        + #"<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>"#
        + #"<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>"#
        + #"<cellXfs count="3">"#
        + #"<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>"#
        + #"<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>"#
        + #"<xf numFmtId="14" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>"#
        + "</cellXfs>"
        + #"<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>"#
        + "</styleSheet>"

    private static func worksheet(_ sheet: Worksheet) -> String {
        var xml = header + #"<worksheet xmlns="\#(mainNS)">"#
        xml += #"<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>"#
        if !sheet.columns.isEmpty {
            xml += #"<cols><col min="1" max="\#(sheet.columns.count)" width="18" customWidth="1"/></cols>"#
        }
        xml += "<sheetData>"
        let allRows = [sheet.columns.map { Cell.text($0) }] + sheet.rows
        for (rowIndex, row) in allRows.enumerated() {
            let r = rowIndex + 1
            xml += #"<row r="\#(r)">"#
            for (columnIndex, cell) in row.enumerated() {
                let ref = "\(columnName(columnIndex))\(r)"
                let style = rowIndex == 0 ? #" s="1""# : ""
                switch cell {
                case .text(let value):
                    xml += #"<c r="\#(ref)"\#(style) t="inlineStr"><is><t xml:space="preserve">\#(escape(value))</t></is></c>"#
                case .number(let value):
                    xml += #"<c r="\#(ref)"\#(style)><v>\#(numberString(value))</v></c>"#
                case .date(let value):
                    xml += #"<c r="\#(ref)" s="2"><v>\#(serialDay(value))</v></c>"#
                case .empty:
                    break
                }
            }
            xml += "</row>"
        }
        xml += "</sheetData></worksheet>"
        return xml
    }

    // MARK: - Helpers

    /// 0 → A, 25 → Z, 26 → AA.
    static func columnName(_ index: Int) -> String {
        var index = index
        var name = ""
        repeat {
            name = String(UnicodeScalar(UInt8(65 + index % 26))) + name
            index = index / 26 - 1
        } while index >= 0
        return name
    }

    /// Excel day number for the local calendar date (1900 date system).
    static func serialDay(_ date: Date) -> Int {
        let calendar = Calendar.current
        let epoch = calendar.date(from: DateComponents(year: 1899, month: 12, day: 30))!
        return calendar.dateComponents([.day], from: epoch, to: calendar.startOfDay(for: date)).day ?? 0
    }

    private static func numberString(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e15 ? String(Int(value)) : String(value)
    }

    private static func sheetName(_ name: String) -> String {
        let cleaned = name.filter { !"[]:*?/\\".contains($0) }
        return String(cleaned.prefix(31))
    }

    static func escape(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "\t", "\n", "\r": result.unicodeScalars.append(scalar)
            default:
                // XML 1.0 forbids other control characters.
                if scalar.value >= 0x20 { result.unicodeScalars.append(scalar) }
            }
        }
        return result
    }
}

/// Uncompressed ("stored") zip archive writer — all .xlsx needs.
struct ZipWriter {
    private var body = Data()
    private var directory = Data()
    private var count: UInt16 = 0

    /// DOS date for 1980-01-01; timestamps don't matter here.
    private static let dosDate: UInt16 = (0 << 9) | (1 << 5) | 1

    mutating func add(_ path: String, _ text: String) {
        add(path, Data(text.utf8))
    }

    mutating func add(_ path: String, _ data: Data) {
        let name = Data(path.utf8)
        let crc = CRC32.checksum(data)
        let size = UInt32(data.count)
        let offset = UInt32(body.count)

        body.appendLittleEndian(UInt32(0x0403_4B50))
        body.appendLittleEndian(UInt16(20))  // version needed
        body.appendLittleEndian(UInt16(0))   // flags
        body.appendLittleEndian(UInt16(0))   // method: stored
        body.appendLittleEndian(UInt16(0))   // time
        body.appendLittleEndian(Self.dosDate)
        body.appendLittleEndian(crc)
        body.appendLittleEndian(size)        // compressed
        body.appendLittleEndian(size)        // uncompressed
        body.appendLittleEndian(UInt16(name.count))
        body.appendLittleEndian(UInt16(0))   // extra length
        body.append(name)
        body.append(data)

        directory.appendLittleEndian(UInt32(0x0201_4B50))
        directory.appendLittleEndian(UInt16(20))  // version made by
        directory.appendLittleEndian(UInt16(20))  // version needed
        directory.appendLittleEndian(UInt16(0))   // flags
        directory.appendLittleEndian(UInt16(0))   // method
        directory.appendLittleEndian(UInt16(0))   // time
        directory.appendLittleEndian(Self.dosDate)
        directory.appendLittleEndian(crc)
        directory.appendLittleEndian(size)
        directory.appendLittleEndian(size)
        directory.appendLittleEndian(UInt16(name.count))
        directory.appendLittleEndian(UInt16(0))   // extra length
        directory.appendLittleEndian(UInt16(0))   // comment length
        directory.appendLittleEndian(UInt16(0))   // disk number
        directory.appendLittleEndian(UInt16(0))   // internal attributes
        directory.appendLittleEndian(UInt32(0))   // external attributes
        directory.appendLittleEndian(offset)
        directory.append(name)

        count += 1
    }

    func finish() -> Data {
        var archive = body
        let directoryOffset = UInt32(archive.count)
        archive.append(directory)
        archive.appendLittleEndian(UInt32(0x0605_4B50))
        archive.appendLittleEndian(UInt16(0))  // this disk
        archive.appendLittleEndian(UInt16(0))  // directory disk
        archive.appendLittleEndian(count)
        archive.appendLittleEndian(count)
        archive.appendLittleEndian(UInt32(directory.count))
        archive.appendLittleEndian(directoryOffset)
        archive.appendLittleEndian(UInt16(0))  // comment length
        return archive
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { i in
        var c = UInt32(i)
        for _ in 0..<8 {
            c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1
        }
        return c
    }

    static func checksum(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for byte in data {
            c = table[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8)
        }
        return c ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
