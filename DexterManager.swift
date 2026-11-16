import Foundation

class DexterManager: ObservableObject {
    private let bridge = DexterBridge()
    
    // Lưu đường dẫn file config vào thư mục Document của app
    private var configPath: String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("dexter_config.txt").path
    }
    
    func saveToFile() {
        let success = bridge.saveConfig(configPath)
        print(success ? "Đã lưu file C++ thành công!" : "Lỗi lưu file")
    }
    
    func loadFromFile() {
        let success = bridge.loadConfig(configPath)
        print(success ? "Đã đọc file C++ thành công!" : "Lỗi đọc file")
    }
    
    func updateModule(index: Int, enabled: Bool) {
        bridge.setModule(Int32(index), enabled: enabled)
    }
    
    func getFPS() -> Float {
        return bridge.getFPS()
    }
}