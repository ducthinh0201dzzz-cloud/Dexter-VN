#pragma once

#include <array>
#include <string>
#include <fstream>
#include <sstream>
#include <algorithm>
#include <chrono>
#include <cmath>

namespace DexterVN {

constexpr int MODULE_COUNT = 22;

static const char* ModuleNames[MODULE_COUNT] = {
    "FluxBrake", "LiftVector", "SilkPulse", "MicroOrbit", "JitterShield", "SafeRoute",
    "SuperCore", "TouchPath", "DeviceModel", "StabilityCore", "FrameFlow", "DisplaySync",
    "ThermalBalance", "LocalRoute", "TouchSample", "PerformanceGuard", "PointerFlow",
    "AccessFlow", "TouchResponse", "DisplayResponse", "RenderSync", "ThermalSync"
};

struct Config {
    float aimSensitivity = 50.0f;
    float dpi = 400.0f;
    float smoothing = 0.35f; // Thêm smoothing cho Trainer

    bool dragAssist = false;
    bool aimStability = false;
    bool recoilControl = false;
    bool fpsOptimization = false;

    int deviceProfile = 0;
    int preset = 0;
    std::array<bool, MODULE_COUNT> modules{};

    void Reset() { *this = Config{}; }
};

// Class xử lý phân tích nét kéo (Trainer)
class StrokeAnalyzer {
    double startX = 0, startY = 0, startTime = 0;
    double lastX = 0, lastY = 0, lastTime = 0;
    double totalDistance = 0;
    double totalTimeMs = 0;
    double sumSpeed = 0;
    double sumSpeedSq = 0;
    int pointCount = 0;
    bool isTracking = false;

public:
    void Begin(double x, double y, double time) {
        startX = lastX = x;
        startY = lastY = y;
        startTime = lastTime = time;
        totalDistance = totalTimeMs = sumSpeed = sumSpeedSq = 0;
        pointCount = 1;
        isTracking = true;
    }

    void Sample(double x, double y, double time) {
        if (!isTracking) return;
        
        double dx = x - lastX;
        double dy = y - lastY;
        double dt = time - lastTime;
        
        double dist = std::sqrt(dx * dx + dy * dy);
        totalDistance += dist;
        
        if (dt > 0) {
            double speed = dist / dt;
            sumSpeed += speed;
            sumSpeedSq += speed * speed;
        }
        
        totalTimeMs += dt;
        lastX = x; lastY = y; lastTime = time;
        pointCount++;
    }

    // Trả về các thông số: distance, duration, straightness, stability, speed
    std::array<double, 5> Finish(double x, double y, double time) {
        if (!isTracking) return {0, 0, 0, 0, 0};
        Sample(x, y, time);
        isTracking = false;

        double straightDist = std::sqrt((x - startX) * (x - startX) + (y - startY) * (y - startY));
        double straightness = totalDistance > 0 ? (straightDist / totalDistance) : 0;
        
        double avgSpeed = pointCount > 1 ? (sumSpeed / (pointCount - 1)) : 0;
        double variance = pointCount > 1 ? (sumSpeedSq / (pointCount - 1)) - (avgSpeed * avgSpeed) : 0;
        double stability = 1.0 / (1.0 + std::sqrt(std::max(0.0, variance))); // Chuẩn hóa từ 0 đến 1

        return {totalDistance, totalTimeMs, straightness, stability, avgSpeed};
    }
};

class Core {
public:
    Config config;
    StrokeAnalyzer stroke;

    void SetSensitivity(float value) { config.aimSensitivity = std::clamp(value, 0.0f, 100.0f); }
    void SetDPI(float value) { config.dpi = std::clamp(value, 100.0f, 1000.0f); }
    void SetSmoothing(float value) { config.smoothing = std::clamp(value, 0.0f, 1.0f); }
    void SetModule(int index, bool enabled) { if (index >= 0 && index < MODULE_COUNT) config.modules[index] = enabled; }
    
    float GetSensitivity() const { return config.aimSensitivity; }
    float GetSmoothing() const { return config.smoothing; }

    bool Save(const std::string& path) const {
        std::ofstream file(path);
        if (!file.is_open()) return false;
        file << config.aimSensitivity << '\n' << config.dpi << '\n' << config.smoothing << '\n';
        file << config.dragAssist << '\n' << config.aimStability << '\n' << config.recoilControl << '\n' << config.fpsOptimization << '\n';
        file << config.deviceProfile << '\n' << config.preset << '\n';
        for (bool value : config.modules) file << value << '\n';
        return file.good();
    }

    bool Load(const std::string& path) {
        std::ifstream file(path);
        if (!file.is_open()) return false;
        Config temp{};
        if (!(file >> temp.aimSensitivity >> temp.dpi >> temp.smoothing)) return false;
        if (!(file >> temp.dragAssist >> temp.aimStability >> temp.recoilControl >> temp.fpsOptimization)) return false;
        if (!(file >> temp.deviceProfile >> temp.preset)) return false;
        for (int i = 0; i < MODULE_COUNT; ++i) { if (!(file >> temp.modules[i])) return false; }
        config = temp;
        return true;
    }
};

} // namespace DexterVN