import SwiftUI

// MARK: - Data types

struct ChartDataPoint: Equatable {
    let date: Date
    let value: Double
}

struct ChartSeries: Equatable {
    let name: String
    let color: Color
    let points: [ChartDataPoint]
}

struct ChartSelection: Equatable {
    let date: Date
    let values: [(name: String, value: Double, color: Color)]

    static func == (lhs: ChartSelection, rhs: ChartSelection) -> Bool {
        lhs.date == rhs.date
    }
}

// MARK: - Single-line weight chart (Home + Progress)

struct SmoothLineChart: View {
    let data: [ChartDataPoint]
    let emaData: [ChartDataPoint]
    let color: Color
    let height: CGFloat
    var showOscillation: Bool = true
    var onSelection: ((ChartSelection?) -> Void)?

    @State private var dragLocation: CGFloat?
    @State private var lastHapticIndex: Int?
    @GestureState private var isDragging = false

    private var allValues: [Double] {
        data.map(\.value) + emaData.map(\.value)
    }

    private var yRange: (min: Double, max: Double) {
        let domain = ChartHelpers.yDomain(for: allValues)
        return (domain.lowerBound, domain.upperBound)
    }

    private var xRange: (min: TimeInterval, max: TimeInterval) {
        guard let first = data.first?.date, let last = data.last?.date else {
            return (0, 1)
        }
        let pad: TimeInterval = 86400 * 0.3
        return (first.timeIntervalSince1970 - pad, last.timeIntervalSince1970 + pad)
    }

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let yr = yRange
            let xr = xRange

            func xPos(_ date: Date) -> CGFloat {
                let t = (date.timeIntervalSince1970 - xr.min) / (xr.max - xr.min)
                return CGFloat(t) * w
            }
            func yPos(_ val: Double) -> CGFloat {
                let t = (val - yr.min) / (yr.max - yr.min)
                return h - CGFloat(t) * h
            }

            // Oscillation bars (thin lines from EMA to daily value)
            if showOscillation {
                for point in data {
                    if let nearest = emaData.min(by: { abs($0.date.timeIntervalSince(point.date)) < abs($1.date.timeIntervalSince(point.date)) }) {
                        let x = xPos(point.date)
                        let y1 = yPos(nearest.value)
                        let y2 = yPos(point.value)
                        var bar = Path()
                        bar.move(to: CGPoint(x: x, y: y1))
                        bar.addLine(to: CGPoint(x: x, y: y2))
                        context.stroke(bar, with: .color(color.opacity(0.35)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    }

                    // Dot at daily value
                    let cx = xPos(point.date)
                    let cy = yPos(point.value)
                    let isLast = point.date == data.last?.date
                    let r: CGFloat = isLast ? 4 : 2.5
                    context.fill(
                        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                        with: .color(color.opacity(isLast ? 0.8 : 0.5))
                    )
                }
            }

            // EMA curve + gradient fill
            if emaData.count >= 2 {
                let emaPoints = emaData.map { CGPoint(x: xPos($0.date), y: yPos($0.value)) }
                let curvePath = catmullRomPath(points: emaPoints)

                // Gradient fill
                var fillPath = curvePath
                fillPath.addLine(to: CGPoint(x: emaPoints.last!.x, y: h))
                fillPath.addLine(to: CGPoint(x: emaPoints.first!.x, y: h))
                fillPath.closeSubpath()
                context.fill(fillPath, with: .linearGradient(
                    Gradient(colors: [color.opacity(0.18), color.opacity(0)]),
                    startPoint: CGPoint(x: w / 2, y: 0),
                    endPoint: CGPoint(x: w / 2, y: h)
                ))

                // Stroke
                context.stroke(curvePath, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }

            // Selection indicator
            if let dragX = dragLocation {
                // Vertical line
                var rule = Path()
                rule.move(to: CGPoint(x: dragX, y: 0))
                rule.addLine(to: CGPoint(x: dragX, y: h))
                context.stroke(rule, with: .color(color.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))

                // Highlighted dot on EMA
                if let selDate = dateAt(x: dragX, width: w) {
                    if let nearest = emaData.min(by: { abs($0.date.timeIntervalSince(selDate)) < abs($1.date.timeIntervalSince(selDate)) }) {
                        let cy = yPos(nearest.value)
                        context.fill(
                            Path(ellipseIn: CGRect(x: dragX - 5, y: cy - 5, width: 10, height: 10)),
                            with: .color(color)
                        )
                        context.fill(
                            Path(ellipseIn: CGRect(x: dragX - 3, y: cy - 3, width: 6, height: 6)),
                            with: .color(.white)
                        )
                    }
                }
            }
        }
        .frame(height: height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isDragging) { _, state, _ in state = true }
                .onChanged { value in
                    let x = min(max(value.location.x, 0), UIScreen.main.bounds.width)
                    dragLocation = x
                    fireSelection(at: x)
                }
                .onEnded { _ in
                    dragLocation = nil
                    lastHapticIndex = nil
                    onSelection?(nil)
                }
        )
        .onChange(of: isDragging) { _, dragging in
            if !dragging {
                dragLocation = nil
                lastHapticIndex = nil
                onSelection?(nil)
            }
        }
    }

    // MARK: - Helpers

    private func dateAt(x: CGFloat, width: CGFloat) -> Date? {
        guard width > 0 else { return nil }
        let xr = xRange
        let t = Double(x / width)
        let ts = xr.min + t * (xr.max - xr.min)
        return Date(timeIntervalSince1970: ts)
    }

    private func fireSelection(at x: CGFloat) {
        guard let size = dragLocation else { return }
        let width = UIScreen.main.bounds.width - 32 // approximate padding
        guard let selDate = dateAt(x: x, width: width > 0 ? width : 300) else { return }

        // Find nearest data point
        var values: [(name: String, value: Double, color: Color)] = []
        if let nearestData = data.min(by: { abs($0.date.timeIntervalSince(selDate)) < abs($1.date.timeIntervalSince(selDate)) }) {
            values.append(("Weight", nearestData.value, color))
        }
        if let nearestEma = emaData.min(by: { abs($0.date.timeIntervalSince(selDate)) < abs($1.date.timeIntervalSince(selDate)) }) {
            values.append(("Trend", nearestEma.value, color))
        }

        // Haptic on crossing a new data point
        if let nearIdx = data.enumerated().min(by: { abs($0.element.date.timeIntervalSince(selDate)) < abs($1.element.date.timeIntervalSince(selDate)) })?.offset {
            if nearIdx != lastHapticIndex {
                lastHapticIndex = nearIdx
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.impactOccurred()
            }
        }

        onSelection?(ChartSelection(date: selDate, values: values))
    }

    /// Catmull-Rom spline through a list of points (smooth curve)
    private func catmullRomPath(points: [CGPoint], alpha: CGFloat = 0.5) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }

        path.move(to: points[0])
        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }

        for i in 0..<points.count - 1 {
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : points[i + 1]

            let d1 = distance(p0, p1)
            let d2 = distance(p1, p2)
            let d3 = distance(p2, p3)

            let d1a = pow(d1, alpha)
            let d2a = pow(d2, alpha)
            let d3a = pow(d3, alpha)

            var b1 = CGPoint.zero
            if d1a * (d1a + d2a) != 0 {
                b1.x = (d1a * d1a * p2.x - d2a * d2a * p0.x + (2 * d1a * d1a + 3 * d1a * d2a + d2a * d2a) * p1.x) / (3 * d1a * (d1a + d2a))
                b1.y = (d1a * d1a * p2.y - d2a * d2a * p0.y + (2 * d1a * d1a + 3 * d1a * d2a + d2a * d2a) * p1.y) / (3 * d1a * (d1a + d2a))
            } else {
                b1 = p1
            }

            var b2 = CGPoint.zero
            if d3a * (d3a + d2a) != 0 {
                b2.x = (d3a * d3a * p1.x - d2a * d2a * p3.x + (2 * d3a * d3a + 3 * d3a * d2a + d2a * d2a) * p2.x) / (3 * d3a * (d3a + d2a))
                b2.y = (d3a * d3a * p1.y - d2a * d2a * p3.y + (2 * d3a * d3a + 3 * d3a * d2a + d2a * d2a) * p2.y) / (3 * d3a * (d3a + d2a))
            } else {
                b2 = p2
            }

            path.addCurve(to: p2, control1: b1, control2: b2)
        }
        return path
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
    }
}

// MARK: - Multi-line compare chart (Friends)

struct SmoothCompareChart: View {
    let series: [ChartSeries]
    let height: CGFloat
    var onSelection: ((ChartSelection?) -> Void)?

    @State private var dragLocation: CGFloat?
    @State private var lastHapticIndex: Int?
    @GestureState private var isDragging = false

    private var allValues: [Double] {
        series.flatMap { $0.points.map(\.value) }
    }

    private var yRange: (min: Double, max: Double) {
        let domain = ChartHelpers.yDomain(for: allValues)
        return (domain.lowerBound, domain.upperBound)
    }

    private var xRange: (min: TimeInterval, max: TimeInterval) {
        let allDates = series.flatMap { $0.points.map(\.date) }
        guard let first = allDates.min(), let last = allDates.max() else {
            return (0, 1)
        }
        let pad: TimeInterval = 86400 * 0.5
        return (first.timeIntervalSince1970 - pad, last.timeIntervalSince1970 + pad)
    }

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let yr = yRange
                let xr = xRange

                func xPos(_ date: Date) -> CGFloat {
                    let t = (date.timeIntervalSince1970 - xr.min) / (xr.max - xr.min)
                    return CGFloat(t) * w
                }
                func yPos(_ val: Double) -> CGFloat {
                    let t = (val - yr.min) / (yr.max - yr.min)
                    return h - CGFloat(t) * h
                }

                // Draw each series
                for s in series {
                    guard s.points.count >= 2 else { continue }
                    let screenPts = s.points.map { CGPoint(x: xPos($0.date), y: yPos($0.value)) }
                    let curvePath = catmullRomPath(points: screenPts)
                    context.stroke(curvePath, with: .color(s.color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }

                // Selection indicator
                if let dragX = dragLocation {
                    // Vertical line
                    var rule = Path()
                    rule.move(to: CGPoint(x: dragX, y: 0))
                    rule.addLine(to: CGPoint(x: dragX, y: h))
                    context.stroke(rule, with: .color(Color.secondary.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))

                    // Dots on each series
                    if let selDate = dateAt(x: dragX, width: w) {
                        for s in series {
                            if let nearest = s.points.min(by: { abs($0.date.timeIntervalSince(selDate)) < abs($1.date.timeIntervalSince(selDate)) }),
                               abs(nearest.date.timeIntervalSince(selDate)) < 86400 {
                                let cy = yPos(nearest.value)
                                context.fill(
                                    Path(ellipseIn: CGRect(x: dragX - 5, y: cy - 5, width: 10, height: 10)),
                                    with: .color(s.color)
                                )
                                context.fill(
                                    Path(ellipseIn: CGRect(x: dragX - 3, y: cy - 3, width: 6, height: 6)),
                                    with: .color(.white)
                                )
                            }
                        }
                    }
                }
            }
            .frame(height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { value in
                        let x = min(max(value.location.x, 0), geo.size.width)
                        dragLocation = x
                        fireSelection(at: x, width: geo.size.width)
                    }
                    .onEnded { _ in
                        dragLocation = nil
                        lastHapticIndex = nil
                        onSelection?(nil)
                    }
            )
            .onChange(of: isDragging) { _, dragging in
                if !dragging {
                    dragLocation = nil
                    lastHapticIndex = nil
                    onSelection?(nil)
                }
            }
        }
        .frame(height: height)
    }

    // MARK: - Helpers

    private func dateAt(x: CGFloat, width: CGFloat) -> Date? {
        guard width > 0 else { return nil }
        let xr = xRange
        let t = Double(x / width)
        let ts = xr.min + t * (xr.max - xr.min)
        return Date(timeIntervalSince1970: ts)
    }

    private func fireSelection(at x: CGFloat, width: CGFloat) {
        guard let selDate = dateAt(x: x, width: width) else { return }

        var values: [(name: String, value: Double, color: Color)] = []
        for s in series {
            if let nearest = s.points.min(by: { abs($0.date.timeIntervalSince(selDate)) < abs($1.date.timeIntervalSince(selDate)) }),
               abs(nearest.date.timeIntervalSince(selDate)) < 86400 {
                values.append((s.name, nearest.value, s.color))
            }
        }

        // Haptic on crossing data points
        let allPts = series.flatMap { $0.points }
        if let nearIdx = allPts.enumerated().min(by: { abs($0.element.date.timeIntervalSince(selDate)) < abs($1.element.date.timeIntervalSince(selDate)) })?.offset {
            if nearIdx != lastHapticIndex {
                lastHapticIndex = nearIdx
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.impactOccurred()
            }
        }

        onSelection?(ChartSelection(date: selDate, values: values))
    }

    private func catmullRomPath(points: [CGPoint], alpha: CGFloat = 0.5) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }

        path.move(to: points[0])
        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }

        for i in 0..<points.count - 1 {
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : points[i + 1]

            let d1 = distance(p0, p1)
            let d2 = distance(p1, p2)
            let d3 = distance(p2, p3)

            let d1a = pow(d1, alpha)
            let d2a = pow(d2, alpha)
            let d3a = pow(d3, alpha)

            var b1 = CGPoint.zero
            if d1a * (d1a + d2a) != 0 {
                b1.x = (d1a * d1a * p2.x - d2a * d2a * p0.x + (2 * d1a * d1a + 3 * d1a * d2a + d2a * d2a) * p1.x) / (3 * d1a * (d1a + d2a))
                b1.y = (d1a * d1a * p2.y - d2a * d2a * p0.y + (2 * d1a * d1a + 3 * d1a * d2a + d2a * d2a) * p1.y) / (3 * d1a * (d1a + d2a))
            } else {
                b1 = p1
            }

            var b2 = CGPoint.zero
            if d3a * (d3a + d2a) != 0 {
                b2.x = (d3a * d3a * p1.x - d2a * d2a * p3.x + (2 * d3a * d3a + 3 * d3a * d2a + d2a * d2a) * p2.x) / (3 * d3a * (d3a + d2a))
                b2.y = (d3a * d3a * p1.y - d2a * d2a * p3.y + (2 * d3a * d3a + 3 * d3a * d2a + d2a * d2a) * p2.y) / (3 * d3a * (d3a + d2a))
            } else {
                b2 = p2
            }

            path.addCurve(to: p2, control1: b1, control2: b2)
        }
        return path
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
    }
}

// MARK: - X-Axis label overlay

struct ChartXAxisLabels: View {
    let dates: [Date]
    let maxLabels: Int

    init(dates: [Date], maxLabels: Int = 5) {
        self.dates = dates
        self.maxLabels = maxLabels
    }

    private var labelDates: [Date] {
        guard dates.count > 1 else { return dates }
        if dates.count <= maxLabels { return dates }
        let step = max(1, (dates.count - 1) / (maxLabels - 1))
        var result: [Date] = []
        for i in stride(from: 0, to: dates.count, by: step) {
            result.append(dates[i])
        }
        if result.last != dates.last { result.append(dates.last!) }
        return result
    }

    var body: some View {
        HStack {
            ForEach(Array(labelDates.enumerated()), id: \.offset) { _, date in
                Text(DateHelpers.formatShort(DateHelpers.formatDate(date)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if date != labelDates.last {
                    Spacer()
                }
            }
        }
    }
}
