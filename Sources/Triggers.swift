import AppKit
import IOKit
import Darwin

final class TriggerMonitor {
    var onBusyChanged: ((Bool) -> Void)?
    var onAwayWhileBusy: (() -> Void)?

    private(set) var busy = false

    private var timer: Timer?
    private var previousTicks: (busy: Double, total: Double)?
    private var cpuBusySince: Date?
    private var lastAwayNotice = Date.distantPast

    private let pollInterval: TimeInterval = 5
    private let cpuThreshold = 0.5
    private let cpuSustain: TimeInterval = 120
    private let idleThreshold: TimeInterval = 180
    private let awayCooldown: TimeInterval = 600

    private let watchedProcesses: Set<String> = [
        "xcodebuild", "swift", "swiftc", "clang", "ld",
        "make", "cmake", "ninja", "cargo", "rustc",
        "go", "zig", "ruby", "ffmpeg",
    ]

    func start() {
        guard timer == nil else { return }
        previousTicks = cpuTicks()

        let t = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        previousTicks = nil
        cpuBusySince = nil
        setBusy(false)
    }

    private func poll() {
        let now = Date()

        let ticks = cpuTicks()
        var cpuBusy = false
        if let ticks, let previous = previousTicks {
            let deltaBusy = ticks.busy - previous.busy
            let deltaTotal = ticks.total - previous.total
            if deltaTotal > 0, deltaBusy / deltaTotal >= cpuThreshold {
                if let since = cpuBusySince {
                    cpuBusy = now.timeIntervalSince(since) >= cpuSustain
                } else {
                    cpuBusySince = now
                }
            } else {
                cpuBusySince = nil
            }
        }
        previousTicks = ticks

        let coding = watchedProcessRunning()
        setBusy(coding || cpuBusy)

        if busy, idleSeconds() >= idleThreshold, now.timeIntervalSince(lastAwayNotice) >= awayCooldown {
            lastAwayNotice = now
            onAwayWhileBusy?()
        }
    }

    private func setBusy(_ value: Bool) {
        guard value != busy else { return }
        busy = value
        if !value { lastAwayNotice = Date.distantPast }
        onBusyChanged?(value)
    }

    private func watchedProcessRunning() -> Bool {
        var pids = [pid_t](repeating: 0, count: 2048)
        let count = pids.withUnsafeMutableBufferPointer { buffer -> Int32 in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count * MemoryLayout<pid_t>.size))
        }
        guard count > 0 else { return false }

        for index in 0..<Int(count) {
            let pid = pids[index]
            guard pid > 0 else { continue }
            var name = [CChar](repeating: 0, count: 4096)
            guard proc_name(pid, &name, UInt32(name.count)) > 0 else { continue }
            let process = String(cString: name).lowercased()
            if watchedProcesses.contains(process) { return true }
        }
        return false
    }

    private func cpuTicks() -> (busy: Double, total: Double)? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let user = Double(info.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3)
        return (user + system + nice, user + system + nice + idle)
    }

    func idleSeconds() -> TimeInterval {
        let port: mach_port_t
        if #available(macOS 12.0, *) {
            port = kIOMainPortDefault
        } else {
            port = kIOMasterPortDefault
        }

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(port, IOServiceMatching("IOHIDSystem"), &iterator) == KERN_SUCCESS else {
            return 0
        }
        defer { IOObjectRelease(iterator) }

        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return 0 }
        defer { IOObjectRelease(entry) }

        guard let property = IORegistryEntryCreateCFProperty(
            entry,
            "HIDIdleTime" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? NSNumber else {
            return 0
        }
        return property.doubleValue / 1_000_000_000
    }
}
