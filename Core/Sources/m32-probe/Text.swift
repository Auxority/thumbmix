import ThumbmixCore

/// How the probe prints what the desk said: "/ch/01/mix/fader f:0.75".
func describe(_ message: OSCMessage) -> String {
    let arguments = message.arguments.map { argument -> String in
        switch argument {
        case .int(let value): "i:\(value)"
        case .float(let value): "f:\(value)"
        case .string(let value): "s:\"\(value)\""
        case .blob(let value): "b:\(value.count) bytes"
        }
    }
    return ([message.address] + arguments).joined(separator: " ")
}

func zeroPadded(_ text: String, to width: Int) -> String {
    String(repeating: "0", count: max(0, width - text.count)) + text
}
