import ThumbmixCore

/// Section 18. The app calls /ch/NN/dyn/mix (p.26) "Comp mix" and lifts only the compressed side by Makeup gain
/// (`TransferCurve.dynamicsOutput`); the M32 manual predates the control, and no source says where makeup sits.
/// Below the threshold nothing is compressed, so the blend alone shows where makeup is.
@MainActor
func probeCompMix() async {
    print("\n== 18. Comp mix. On the DESK, on channel 1 (a steady signal well below 0 dBFS, fader 0 dB): compressor")
    print("threshold 0 dB, ratio 4, knee 0, makeup +6 dB, mix 50 %, then press Enter.")
    _ = readLine()
    print(await askNode("ch/01/dyn") ?? "ch/01/dyn NO REPLY")
    let taps = [
        MeterTap("post-fade", [.string("/meters/6"), .int(0)], 3),
        MeterTap("comp gain", [.string("/meters/6"), .int(0)], 2),
    ]
    let blend = await compareTaps(taps, "channel 1's compressor OFF", "its compressor ON")
    print("RESULT: \(change(blend?.first)), comp gain \(change(blend?.last)) (about 0 = nothing was compressed).")
    print("About +3.5 dB = makeup lifts the compressed side only (the app's curve); about +6 dB = makeup comes after")
    print("the blend: fix TransferCurve.dynamicsOutput.")
    print("Also note the name the desk's dynamics screen gives the mix control: the app says \"Comp mix\".")
    print("Put channel 1's compressor back as the show needs it.")
}
