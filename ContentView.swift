import SwiftUI
import FirebaseFirestore
import UIKit

// ==========================================
// MARK: - MODELS & STORE (Dành cho Trainer)
// ==========================================
struct SessionResult: Identifiable, Codable {
    var id = UUID()
    var date = Date()
    var distance: Double
    var duration: Double
    var speed: Double
    var straightness: Double
    var stability: Double
}

struct Preset: Codable, Identifiable {
    var id = UUID()
    var name: String
    var sensitivity: Double
    var smoothing: Double
}

final class TrainerStore: ObservableObject {
    @Published var results: [SessionResult] = []
    @Published var presets: [Preset] = []
    @Published var sensitivity: Double = 50 {
        didSet { DexterBridge.setSensitivity(Float(sensitivity)) }
    }
    @Published var smoothing: Double = 0.35 {
        didSet { DexterBridge.setSmoothing(Float(smoothing)) }
    }
    
    init() { 
        load()
        sensitivity = Double(DexterBridge.sensitivity())
        smoothing = Double(DexterBridge.smoothing())
    }
    
    var folder: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    
    func save() {
        if let d = try? JSONEncoder().encode(results) { try? d.write(to: folder.appendingPathComponent("sessions.json")) }
        if let d = try? JSONEncoder().encode(presets) { try? d.write(to: folder.appendingPathComponent("presets.json")) }
    }
    
    func load() {
        if let d = try? Data(contentsOf: folder.appendingPathComponent("sessions.json")), let x = try? JSONDecoder().decode([SessionResult].self, from: d) { results = x }
        if let d = try? Data(contentsOf: folder.appendingPathComponent("presets.json")), let x = try? JSONDecoder().decode([Preset].self, from: d) { presets = x }
    }
    
    func addPreset(_ name: String) { presets.append(Preset(name: name, sensitivity: sensitivity, smoothing: smoothing)); save() }
    func apply(_ p: Preset) { sensitivity = p.sensitivity; smoothing = p.smoothing }
    func add(_ r: SessionResult) { results.insert(r, at: 0); if results.count > 100 { results.removeLast() }; save() }
}

// ==========================================
// MARK: - ROUTER (Login Check)
// ==========================================
struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var isCheckingAuth = true
    
    var body: some View {
        Group {
            if isCheckingAuth {
                ProgressView("Đang kiểm tra bản quyền...")
            } else if isAuthenticated {
                MainTabView(isAuthenticated: $isAuthenticated)
            } else {
                LoginView(isAuthenticated: $isAuthenticated)
            }
        }
        .onAppear {
            if let savedKey = UserDefaults.standard.string(forKey: "saved_license_key"), !savedKey.isEmpty {
                isAuthenticated = true
            }
            isCheckingAuth = false
        }
    }
}

// ==========================================
// MARK: - LOGIN VIEW (Nhập Key)
// ==========================================
struct LoginView: View {
    @Binding var isAuthenticated: Bool
    @State private var licenseKey = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let accentStart = Color(red: 0.35, green: 0.55, blue: 1.0)
    private let accentEnd   = Color(red: 0.65, green: 0.35, blue: 1.0)

    private func getDeviceUDID() -> String { UIDevice.current.identifierForVendor?.uuidString ?? "UNKNOWN" }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(.systemGroupedBackground), .blue.opacity(0.1)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 60))
                    .foregroundStyle(LinearGradient(colors: [accentStart, accentEnd], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(24).background(RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial))
                    .shadow(color: .black.opacity(0.1), radius: 15, y: 10)

                VStack(spacing: 6) {
                    Text("DEXTER VN").font(.system(size: 32, weight: .black, design: .rounded))
                    Text("HỆ THỐNG BẢN QUYỀN").font(.caption.weight(.semibold)).tracking(2.5).foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "key.fill").foregroundStyle(.orange)
                        TextField("Nhập License Key...", text: $licenseKey)
                            .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    }
                    if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading) }
                    
                    Button(action: validateKey) {
                        HStack(spacing: 8) {
                            if isLoading { ProgressView().tint(.white) } else {
                                Image(systemName: "lock.open.fill")
                                Text("KÍCH HOẠT").fontWeight(.bold).tracking(1.2)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(LinearGradient(colors: [accentStart, accentEnd], startPoint: .leading, endPoint: .trailing))
                        .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(licenseKey.isEmpty || isLoading)
                }
                .padding(20).background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 24)
                Spacer()
            }
        }
    }

    private func validateKey() {
        isLoading = true; errorMessage = nil
        let db = Firestore.firestore()
        let keyInput = licenseKey.trimmingCharacters(in: .whitespaces)
        let currentUDID = getDeviceUDID()
        
        db.collection("Keys").document(keyInput).getDocument { snapshot, error in
            isLoading = false
            if error != nil { errorMessage = "Lỗi kết nối mạng."; return }
            guard let document = snapshot, document.exists, let data = document.data() else {
                errorMessage = "Key không hợp lệ hoặc không tồn tại."; return
            }
            if let isLocked = data["is_locked"] as? Bool, isLocked == true {
                errorMessage = "Key này đã bị Admin khóa."; return
            }
            
            if let savedUDID = data["device_id"] as? String, !savedUDID.isEmpty {
                if savedUDID != currentUDID { errorMessage = "Key đã kích hoạt trên thiết bị khác."; return }
                UserDefaults.standard.set(keyInput, forKey: "saved_license_key")
                withAnimation { isAuthenticated = true }
            } else {
                db.collection("Keys").document(keyInput).updateData(["device_id": currentUDID]) { err in
                    if err == nil {
                        UserDefaults.standard.set(keyInput, forKey: "saved_license_key")
                        withAnimation { isAuthenticated = true }
                    }
                }
            }
        }
    }
}

// ==========================================
// MARK: - MAIN TAB VIEW
// ==========================================
struct MainTabView: View {
    @Binding var isAuthenticated: Bool
    @StateObject private var trainerStore = TrainerStore()
    
    var body: some View {
        TabView {
            DashboardView(isAuthenticated: $isAuthenticated)
                .tabItem { Label("Modules", systemImage: "square.grid.2x2") }
            
            TrainerView(store: trainerStore)
                .tabItem { Label("Trainer", systemImage: "scope") }
            
            StatsView(store: trainerStore)
                .tabItem { Label("Stats", systemImage: "chart.bar") }
        }
        .tint(Color(red: 0.35, green: 0.55, blue: 1.0))
    }
}

// ==========================================
// MARK: - DASHBOARD VIEW (Liquid Glass Modules)
// ==========================================
private enum Theme {
    static let accentStart = Color(red: 0.35, green: 0.55, blue: 1.0)
    static let accentEnd   = Color(red: 0.65, green: 0.35, blue: 1.0)
    static let glassStroke = LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let cardCorner: CGFloat = 20
}

private struct GlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(16).background(RoundedRectangle(cornerRadius: Theme.cardCorner).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardCorner).strokeBorder(Theme.glassStroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }
}

struct DashboardView: View {
    @Binding var isAuthenticated: Bool
    @StateObject private var dexterManager = DexterManager()
    
    @AppStorage("dexter_enabled_features") private var enabledRaw = ""
    @AppStorage("aim_sensitivity") private var aimSensitivity = 50.0
    @AppStorage("dpi_setting") private var dpiSetting = 400.0
    @State private var status = "Sẵn sàng"

    private let modules: [(String, String)] = [
        ("FluxBrake", "⚙️"), ("LiftVector", "🚀"), ("SilkPulse", "🪶"), ("MicroOrbit", "🧩"),
        ("JitterShield", "🛡️"), ("SafeRoute", "🌐"), ("SuperCore", "💎"), ("TouchPath", "🔗"),
        ("DeviceModel", "📱"), ("StabilityCore", "🧠"), ("FrameFlow", "🎞️"), ("DisplaySync", "📺"),
        ("ThermalBalance", "❄️"), ("LocalRoute", "📶"), ("TouchSample", "⚡"), ("PerformanceGuard", "🛡️"),
        ("PointerFlow", "🖱️"), ("AccessFlow", "🔌"), ("TouchResponse", "✨"), ("DisplayResponse", "🌈"),
        ("RenderSync", "🌀"), ("ThermalSync", "🔥")
    ]

    private var enabledIDs: Set<String> { Set(enabledRaw.split(separator: ",").map(String.init)) }

    private func setModule(_ name: String, enabled: Bool) {
        var values = enabledIDs
        if enabled { values.insert(name) } else { values.remove(name) }
        enabledRaw = values.sorted().joined(separator: ",")
        withAnimation { status = "\(name): \(enabled ? "Đã bật" : "Đã tắt")" }
        
        // Gọi C++ qua DexterManager (Theo file ghi chú của bạn)
        if let index = modules.firstIndex(where: { $0.0 == name }) {
            dexterManager.updateModule(index: index, enabled: enabled)
        }
    }

    private func logout() {
        UserDefaults.standard.removeObject(forKey: "saved_license_key")
        withAnimation { isAuthenticated = false }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                LinearGradient(colors: [.blue.opacity(0.1), .indigo.opacity(0.05)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 6) {
                            Text("DEXTER VN").font(.system(size: 30, weight: .black, design: .rounded))
                            Text("KEY & CONFIGURATION PANEL").font(.caption.weight(.medium)).tracking(2.2).foregroundStyle(.secondary)
                        }.padding(.top, 8)

                        HStack(spacing: 10) {
                            Circle().fill(status.contains("Đã bật") ? Color.green : Color.accentColor).frame(width: 9, height: 9)
                            Text(status).font(.footnote.weight(.medium)).lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .overlay(Capsule().strokeBorder(Theme.glassStroke, lineWidth: 1))

                        VStack(alignment: .leading, spacing: 12) {
                            Text("AIM & TOUCH").font(.subheadline.weight(.bold)).tracking(0.8)
                            GlassCard {
                                VStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text("Aim Sensitivity").font(.subheadline.weight(.medium))
                                            Spacer()
                                            Text("\(Int(aimSensitivity))").font(.footnote.monospacedDigit().weight(.bold)).foregroundStyle(Theme.accentStart)
                                                .padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(Theme.accentStart.opacity(0.12)))
                                        }
                                        Slider(value: $aimSensitivity, in: 0...100).tint(Theme.accentStart)
                                            .onChange(of: aimSensitivity) { newValue in
                                                DexterBridge.setSensitivity(Float(newValue))
                                            }
                                    }
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text("DPI Settings").font(.subheadline.weight(.medium))
                                            Spacer()
                                            Text("\(Int(dpiSetting))").font(.footnote.monospacedDigit().weight(.bold)).foregroundStyle(Theme.accentEnd)
                                                .padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(Theme.accentEnd.opacity(0.12)))
                                        }
                                        Slider(value: $dpiSetting, in: 100...800).tint(Theme.accentEnd)
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("DEXTER MODULES · \(modules.count)").font(.subheadline.weight(.bold)).tracking(0.8)
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(modules, id: \.0) { item in
                                    let isOn = enabledIDs.contains(item.0)
                                    HStack(spacing: 10) {
                                        Text(item.1).font(.title3)
                                        Text(item.0).font(.system(.caption, design: .rounded).weight(.semibold)).lineLimit(1)
                                        Spacer(minLength: 0)
                                        Toggle("", isOn: Binding(
                                            get: { isOn },
                                            set: { setModule(item.0, enabled: $0) }
                                        )).labelsHidden().tint(Theme.accentStart).scaleEffect(0.75)
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(isOn ? AnyShapeStyle(LinearGradient(colors: [Theme.accentStart.opacity(0.6), Theme.accentEnd.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Theme.glassStroke), lineWidth: isOn ? 1.2 : 0.8))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 30)
                }
            }
            .navigationTitle("ĐỨC THỊNH VN").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: logout) { Image(systemName: "rectangle.portrait.and.arrow.right").foregroundStyle(Theme.accentStart) }
                }
            }
        }
    }
}

// ==========================================
// MARK: - TRAINER VIEW (Từ file của bạn)
// ==========================================
enum TrainingMode { case normal, steady, speed }

struct TrainerView: View {
    @ObservedObject var store: TrainerStore
    @State private var mode: TrainingMode = .normal
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Điều chỉnh luyện tập") {
                    VStack(alignment: .leading) {
                        Text("Sensitivity: \(Int(store.sensitivity))")
                        Slider(value: $store.sensitivity, in: 0...100)
                    }
                    VStack(alignment: .leading) {
                        Text("Smoothness: \(Int(store.smoothing * 100))%")
                        Slider(value: $store.smoothing, in: 0.02...1)
                    }
                    Text("Các thông số chỉ áp dụng trong DEXTER Trainer.")
                        .font(.caption).foregroundColor(.secondary)
                }
                
                Section("Bắt đầu") {
                    NavigationLink("Tự do", destination: TrainingPlayView(store: store, mode: .normal))
                    NavigationLink("Bài tập độ ổn định", destination: TrainingPlayView(store: store, mode: .steady))
                    NavigationLink("Bài tập tốc độ", destination: TrainingPlayView(store: store, mode: .speed))
                }
                
                Section("Preset") {
                    Button("Lưu preset hiện tại") {
                        store.addPreset("Preset \(store.presets.count + 1)")
                    }
                    ForEach(store.presets) { p in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(p.name)
                                Text("Sens \(Int(p.sensitivity)) · Smooth \(Int(p.smoothing * 100))%").font(.caption)
                            }
                            Spacer()
                            Button("Dùng") { store.apply(p) }
                        }
                    }
                }
            }
            .navigationTitle("Trainer")
        }
    }
}

struct TrainingPlayView: View {
    @ObservedObject var store: TrainerStore
    var mode: TrainingMode
    
    @State private var start: CGPoint?
    @State private var current: CGPoint = .zero
    @State private var target = CGPoint(x: 0.5, y: 0.25)
    @State private var begun = Date()
    @State private var message = "Chạm mục tiêu rồi kéo đến vòng đích"
    @State private var completed = 0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    HStack {
                        Text(modeTitle).font(.headline)
                        Spacer()
                        Text("Lượt \(completed)").foregroundColor(.cyan)
                    }.padding()
                    
                    Text(message).font(.caption).foregroundColor(.white).padding(.horizontal)
                    
                    Spacer()
                    Circle().stroke(Color.cyan, lineWidth: 3).frame(width: 62, height: 62)
                        .position(x: target.x * geo.size.width, y: target.y * geo.size.height)
                    Spacer()
                    
                    Text("Kéo bằng tay trong vùng luyện tập").font(.caption).foregroundColor(.gray).padding(.bottom, 24)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { v in
                            if start == nil {
                                start = v.startLocation
                                begun = Date()
                                DexterBridge.beginStroke(v.startLocation, timestamp: nowMs)
                            }
                            current = v.location
                            DexterBridge.sampleStroke(v.location, timestamp: nowMs)
                        }
                        .onEnded { v in
                            let dict = DexterBridge.finishStroke(v.location, timestamp: nowMs)
                            let dist = (dict["distance"] as? Double ?? 0)
                            let dur = (dict["duration"] as? Double ?? 0)
                            let straight = (dict["straightness"] as? Double ?? 0)
                            let stable = (dict["stability"] as? Double ?? 0)
                            
                            store.add(SessionResult(distance: dist, duration: dur, speed: dict["speed"] as? Double ?? 0, straightness: straight, stability: stable))
                            
                            completed += 1
                            message = "Độ thẳng \(Int(straight * 100))% · ổn định \(Int(stable * 100))%"
                            start = nil
                            target = CGPoint(x: CGFloat.random(in: 0.25...0.75), y: CGFloat.random(in: 0.2...0.65))
                        }
                )
                
                if let s = start {
                    Path { p in
                        p.move(to: s)
                        p.addLine(to: current)
                    }.stroke(Color.orange, lineWidth: 4)
                    Circle().fill(Color.orange).frame(width: 12, height: 12).position(current)
                }
            }
        }
        .navigationTitle("Luyện kéo tâm").navigationBarTitleDisplayMode(.inline)
    }
    
    var modeTitle: String {
        switch mode {
        case .normal: return "Tự do"
        case .steady: return "Ổn định"
        case .speed: return "Tốc độ"
        }
    }
    var nowMs: Double { Date().timeIntervalSince1970 * 1000 }
}

// ==========================================
// MARK: - STATS VIEW (Từ file của bạn)
// ==========================================
struct StatsView: View {
    @ObservedObject var store: TrainerStore
    
    var body: some View {
        NavigationStack {
            List {
                Section("Thống kê") {
                    Text("Tổng lượt: \(store.results.count)")
                    Text("Độ thẳng trung bình: \(avgStraight, specifier: "%.0f")%")
                    Text("Ổn định trung bình: \(avgStable, specifier: "%.0f")%")
                }
                Section("Lịch sử") {
                    ForEach(store.results) { r in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(r.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                            Text("Độ thẳng \(r.straightness * 100, specifier: "%.1f")% · Ổn định \(r.stability * 100, specifier: "%.1f")%")
                            Text("Quãng \(r.distance, specifier: "%.0f") px · \(r.duration, specifier: "%.0f") ms").font(.caption)
                        }
                    }
                    .onDelete { store.results.remove(atOffsets: $0); store.save() }
                }
            }
            .navigationTitle("Tiến trình")
        }
    }
    
    var avgStraight: Double {
        store.results.isEmpty ? 0 : store.results.map { $0.straightness }.reduce(0, +) / Double(store.results.count) * 100
    }
    var avgStable: Double {
        store.results.isEmpty ? 0 : store.results.map { $0.stability }.reduce(0, +) / Double(store.results.count) * 100
    }
}