//
//  ContentView.swift
//  Truck-Driver
//
//  Created by Diarmuid on 27/12/2024.
//

import SwiftUI
import PDFKit

struct Load: Identifiable {
    var id = UUID()
    var category: LoadCategory
    var origin: String
    var destination: String
    var weight: Double
    var notes: String
    var date: Date
    var truckNumber: String
    var loadNumber: Int
}

enum LoadCategory: String, CaseIterable, Identifiable {
    case generalFreight = "General Freight"
    case dryVanLoads = "Dry Van Loads"
    case flatbedLoads = "Flatbed Loads"
    case refrigeratedLoads = "Refrigerated (Reefer) Loads"
    case tankerLoads = "Tanker Loads"
    case hazmatLoads = "Hazmat/ADR Loads"
    case oversizedLoads = "Oversized Loads"
    case bulkMaterials = "Bulk Materials"
    case livestockLoads = "Livestock Loads"
    case highValueLoads = "High-Value/Expedited Loads"

    var id: String { self.rawValue }
}

struct ContentView: View {
    @State private var loads: [Load] = [
        Load(category: .generalFreight, origin: "New York", destination: "Los Angeles", weight: 1000, notes: "Handle with care", date: Date(), truckNumber: "TRK123", loadNumber: 1),
        Load(category: .dryVanLoads, origin: "Chicago", destination: "Houston", weight: 500, notes: "Fragile", date: Date(), truckNumber: "TRK456", loadNumber: 2),
        Load(category: .flatbedLoads, origin: "Miami", destination: "Seattle", weight: 2000, notes: "Urgent delivery", date: Date(), truckNumber: "TRK789", loadNumber: 3)
    ]
    
    @State private var newLoad = Load(category: .tankerLoads, origin: "", destination: "", weight: 0, notes: "", date: Date(), truckNumber: "", loadNumber: 1)
    @State private var defaultTruckNumber = ""

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    DatePicker("Date", selection: $newLoad.date, displayedComponents: .date)
                        .onChange(of: newLoad.date) { _ in
                            newLoad.loadNumber = nextLoadNumber(for: newLoad.date)
                        }
                    TextField("Truck Number", text: $newLoad.truckNumber)
                        .onChange(of: newLoad.truckNumber) { newValue in
                            defaultTruckNumber = newValue
                        }
                    TextField("Load Number", value: $newLoad.loadNumber, formatter: integerFormatter)
                        .disabled(true) // Disable editing of load number
                    
                    Picker("Category", selection: $newLoad.category) {
                        ForEach(LoadCategory.allCases) { category in
                            Text(category.rawValue.capitalized).tag(category)
                        }
                    }
                    
                    TextField("Origin", text: $newLoad.origin)
                    TextField("Destination", text: $newLoad.destination)
                    TextField("Weight", value: $newLoad.weight, formatter: integerFormatter)
                    TextField("Notes", text: $newLoad.notes)
                    
                    Button("Add Load") {
                        loads.append(newLoad)
                        newLoad = Load(category: .tankerLoads, origin: "", destination: "", weight: 0, notes: "", date: newLoad.date, truckNumber: defaultTruckNumber, loadNumber: nextLoadNumber(for: newLoad.date))
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                
                Spacer() // Pushes the NavigationLink to the bottom

                NavigationLink(destination: LoadListView(loads: $loads)) {
                    Text("View Loads")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Load Management")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func nextLoadNumber(for date: Date) -> Int {
        let calendar = Calendar.current
        let loadsForDate = loads.filter { calendar.isDate($0.date, inSameDayAs: date) }
        return (loadsForDate.map { $0.loadNumber }.max() ?? 0) + 1
    }
}

struct LoadListView: View {
    @Binding var loads: [Load]
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isFiltering = false

    var body: some View {
        VStack {
            HStack {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    .labelsHidden()
                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    .labelsHidden()
                Button("Apply Filter") {
                    isFiltering = true
                }
                .padding(.leading)
            }
            .padding(.horizontal)
            
            List {
                ForEach(filteredLoads) { load in
                    NavigationLink(destination: LoadDetailView(load: load)) {
                        VStack(alignment: .leading) {
                            Text("Date: \(load.date, formatter: DateFormatter.loadDateFormatter)")
                            Text("Truck Number: \(load.truckNumber)")
                            Text("Load Number: \(load.loadNumber)")
                            
                            Text("Category: \(load.category.rawValue.capitalized)")
                            Text("Origin: \(load.origin)")
                            Text("Destination: \(load.destination)")
                            Text("Weight: \(Int(load.weight)) kg")
                            Text("Notes: \(load.notes)")
                        }
                        .padding()
                    }
                }
                .onDelete(perform: deleteLoad)
            }
            
            Button("Export to PDF") {
                exportToPDF()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .navigationTitle("Load List")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var filteredLoads: [Load] {
        if isFiltering {
            return loads.filter { load in
                load.date >= startDate && load.date <= endDate
            }
        } else {
            return loads
        }
    }
    
    private func deleteLoad(at offsets: IndexSet) {
        loads.remove(atOffsets: offsets)
    }
    
    private func exportToPDF() {
        let pdfDocument = PDFDocument()
        let pdfPage = PDFPage(image: generateImageFromLoads())!
        pdfDocument.insert(pdfPage, at: 0)
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("LoadList.pdf")
        pdfDocument.write(to: tempURL)
        
        let activityViewController = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let topController = UIApplication.shared.windows.first?.rootViewController {
            topController.present(activityViewController, animated: true, completion: nil)
        }
    }
    
    private func generateImageFromLoads() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 612, height: 792)) // A4 size
        return renderer.image { ctx in
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .paragraphStyle: paragraphStyle
            ]
            
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .paragraphStyle: paragraphStyle
            ]
            
            // Calculate totals
            let totalWeight = filteredLoads.reduce(0) { $0 + $1.weight }
            let totalLoads = filteredLoads.count
            
            // Draw header
            let headerText = "Load Report\nTotal Loads: \(totalLoads)\nTotal Weight: \(Int(totalWeight)) kg"
            headerText.draw(at: CGPoint(x: 20, y: 20), withAttributes: headerAttributes)
            
            // Draw a line under the header
            ctx.cgContext.move(to: CGPoint(x: 20, y: 70))
            ctx.cgContext.addLine(to: CGPoint(x: 592, y: 70))
            ctx.cgContext.strokePath()
            
            // Column headers
            let columnHeaders = ["Date", "Truck No.", "Load No.", "Category", "Origin", "Destination", "Weight", "Notes"]
            let columnWidths: [CGFloat] = [60, 80, 60, 100, 80, 80, 60, 120] // Increased width for Notes
            var xOffset: CGFloat = 20
            for (index, header) in columnHeaders.enumerated() {
                header.draw(at: CGPoint(x: xOffset, y: 80), withAttributes: headerAttributes)
                xOffset += columnWidths[index]
            }
            
            // Draw a line under the column headers
            ctx.cgContext.move(to: CGPoint(x: 20, y: 100))
            ctx.cgContext.addLine(to: CGPoint(x: 592, y: 100))
            ctx.cgContext.strokePath()
            
            var yOffset: CGFloat = 110
            for load in filteredLoads {
                let dateString = DateFormatter.shortDateFormatter.string(from: load.date)
                let rowValues = [
                    dateString,
                    load.truckNumber,
                    String(load.loadNumber),
                    load.category.rawValue.capitalized,
                    load.origin,
                    load.destination,
                    "\(Int(load.weight)) kg",
                    load.notes
                ]
                
                xOffset = 20
                for (index, value) in rowValues.enumerated() {
                    if index == rowValues.count - 1 { // Notes column
                        drawWrappedText(value, at: CGPoint(x: xOffset, y: yOffset), maxWidth: columnWidths[index], attributes: bodyAttributes, context: ctx.cgContext)
                    } else {
                        value.draw(at: CGPoint(x: xOffset, y: yOffset), withAttributes: bodyAttributes)
                    }
                    xOffset += columnWidths[index]
                }
                yOffset += 40 // Adjusted for potential wrapping
                
                // Draw a line between rows
                ctx.cgContext.move(to: CGPoint(x: 20, y: yOffset))
                ctx.cgContext.addLine(to: CGPoint(x: 592, y: yOffset))
                ctx.cgContext.strokePath()
            }
        }
    }
    
    private func drawWrappedText(_ text: String, at point: CGPoint, maxWidth: CGFloat, attributes: [NSAttributedString.Key: Any], context: CGContext) {
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
        var currentRange = CFRange(location: 0, length: 0)
        var currentY = point.y
        
        while currentRange.location < attributedText.length {
            let path = CGPath(rect: CGRect(x: point.x, y: currentY, width: maxWidth, height: .greatestFiniteMagnitude), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, currentRange, path, nil)
            CTFrameDraw(frame, context)
            
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            currentRange = CFRange(location: currentRange.location + visibleRange.length, length: 0)
            currentY += 20 // Line height
        }
    }
}

struct LoadDetailView: View {
    @State var load: Load

    var body: some View {
        Form {
            DatePicker("Date", selection: $load.date, displayedComponents: .date)
            TextField("Truck Number", text: $load.truckNumber)
            TextField("Load Number", text: Binding(
                get: { String(load.loadNumber) },
                set: { load.loadNumber = Int($0) ?? load.loadNumber }
            ))
            
            Picker("Category", selection: $load.category) {
                ForEach(LoadCategory.allCases) { category in
                    Text(category.rawValue.capitalized).tag(category)
                }
            }
            
            TextField("Origin", text: $load.origin)
            TextField("Destination", text: $load.destination)
            TextField("Weight", value: $load.weight, formatter: integerFormatter)
            TextField("Notes", text: $load.notes)
        }
        .navigationTitle("Edit Load")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// NumberFormatter for integer values
private let integerFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return formatter
}()

// DateFormatter extension for consistent date formatting
extension DateFormatter {
    static let loadDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter
    }()
}

#Preview {
    ContentView()
}
