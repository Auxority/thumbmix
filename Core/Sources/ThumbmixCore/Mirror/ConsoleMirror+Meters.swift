import Foundation

extension ConsoleMirror {
    func applyMeters(_ message: OSCMessage) {
        guard case .blob(let blob)? = message.arguments.first else { return }
        let readings = MeterBanks.readings(
            address: message.address, values: MeterBlob.floats(from: blob))
        for (strip, reading) in readings {
            guard let cell = meterCells[strip] else { continue }
            // Explicit equality checks: older Observation versions notify on every write, which redraws idle meters at 20 Hz.
            if cell.level != reading.level { cell.level = reading.level }
            if let gate = reading.gateGain, cell.gateGain != gate { cell.gateGain = gate }
            if let dynamics = reading.dynamicsGain, cell.dynamicsGain != dynamics {
                cell.dynamicsGain = dynamics
            }
        }
    }
}
