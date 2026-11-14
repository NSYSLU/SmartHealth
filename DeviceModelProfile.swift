import Foundation

struct DeviceModelProfile {
    let recommended: ModelTier
    let memoryGB: Int
    let reason: String

    static var current: DeviceModelProfile {
        let memory = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
        if memory >= 8 { return DeviceModelProfile(recommended: .deep, memoryGB: memory, reason: "设备内存充足，适合更细致的长期分析") }
        if memory >= 4 { return DeviceModelProfile(recommended: .balanced, memoryGB: memory, reason: "平衡速度与分析深度，适合日常使用") }
        return DeviceModelProfile(recommended: .fast, memoryGB: memory, reason: "优先保证响应速度和续航")
    }
}
