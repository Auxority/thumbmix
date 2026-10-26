import Testing

@testable import ThumbmixCore

private let fontein = NetworkConsole(host: "192.168.1.62", name: "De Fontein FOH", model: "M32")
private let zaal = NetworkConsole(host: "10.10.0.20", name: "Zaal 2", model: "M32")
private let guest = NetworkConsole(host: "192.168.1.80", name: "M32-02-4A-53", model: "M32")
private let x32 = NetworkConsole(host: "192.168.1.90", name: "X32-RACK", model: "X32")

struct KnownConsolesTests {
    @Test func theLastConsoleConnectedToComesFirst() {
        var known = KnownConsoles()
        known.remember(zaal)
        known.remember(fontein)
        known.remember(zaal)

        #expect(known.lastUsed == zaal)
        #expect(known.others == [fontein])
    }

    /// Two venues' desks can share a common address like 192.168.1.50; each keeps its own row.
    @Test func consolesSharingAnAddressStayApart() {
        var known = KnownConsoles()
        known.remember(NetworkConsole(host: "192.168.1.50", name: "Venue A", model: "M32"))
        known.remember(NetworkConsole(host: "192.168.1.50", name: "Venue B", model: "M32"))

        #expect(known.all.map(\.name) == ["Venue B", "Venue A"])
    }

    @Test func aForgottenConsoleLeaves() {
        var known = KnownConsoles([fontein, zaal])
        known.forget(zaal)

        #expect(known.all == [fontein])
    }

    @Test func survivesBeingStored() {
        let known = KnownConsoles([fontein, zaal])

        #expect(KnownConsoles(stored: known.stored) == known)
    }

    /// Launch arguments and older app versions can leave anything under the key.
    @Test func unreadableStoredEntriesAreSkipped() {
        let stored: Any = [["host": "192.168.1.62", "name": "De Fontein FOH", "model": "M32"], ["host": "x"], "junk"]

        #expect(KnownConsoles(stored: stored).all == [fontein])
        #expect(KnownConsoles(stored: nil).all.isEmpty)
    }
}

struct ConsoleSightingsTests {
    @Test func nothingIsOnlineBeforeTheScanAnswers() {
        let sightings = ConsoleSightings()

        #expect(sightings.presence(of: fontein) == .unknown)
    }

    @Test func aConsoleIsOnlineOnlyWhenItAnsweredTheLatestScan() {
        var sightings = ConsoleSightings()
        let known = KnownConsoles([fontein, zaal])
        sightings.scanned([fontein], known: known)
        #expect(sightings.presence(of: fontein) == .online)
        #expect(sightings.presence(of: zaal) == .notFound)

        sightings.scanned([], known: known)
        #expect(sightings.presence(of: fontein) == .notFound)
    }

    /// Another desk answering on a remembered address is a different console, not the remembered one.
    @Test func aDifferentDeskOnARememberedAddressIsNew() {
        var sightings = ConsoleSightings()
        let known = KnownConsoles([fontein])
        let other = NetworkConsole(host: fontein.host, name: "Other venue", model: "M32")
        sightings.scanned([other], known: known)

        #expect(sightings.presence(of: fontein) == .notFound)
        #expect(sightings.rows(known: known) == [other])
    }

    /// The log says why a remembered console is Not found: a renamed desk, a new address, or silence.
    @Test func aMissSaysWhatTheScanSawInstead() {
        var sightings = ConsoleSightings()
        #expect(sightings.sighting(of: fontein) == .notScanned)

        let renamed = NetworkConsole(host: fontein.host, name: "FOH", model: "M32")
        let moved = NetworkConsole(host: "192.168.1.63", name: fontein.name, model: "M32")
        sightings.scanned([renamed], known: KnownConsoles([fontein]))
        #expect(sightings.sighting(of: fontein) == .addressAnsweredAs(name: "FOH"))
        sightings.scanned([moved], known: KnownConsoles([fontein]))
        #expect(sightings.sighting(of: fontein) == .nameAnsweredFrom(host: "192.168.1.63"))
        sightings.scanned([], known: KnownConsoles([fontein]))
        #expect(sightings.sighting(of: fontein) == .noReply)
        sightings.scanned([fontein], known: KnownConsoles([fontein]))
        #expect(sightings.sighting(of: fontein) == .answered(model: "M32"))
    }

    @Test func anotherConsoleModelIsNotAnM32() {
        var sightings = ConsoleSightings()
        sightings.scanned([x32], known: KnownConsoles())

        #expect(sightings.presence(of: x32) == .notAnM32)
    }

    /// Rows never move under a thumb: a console found later goes after the rows already shown.
    @Test func rowsKeepTheirPlaceAcrossScans() {
        var sightings = ConsoleSightings()
        let known = KnownConsoles([fontein, zaal])
        sightings.scanned([x32, fontein], known: known)
        sightings.scanned([guest, x32], known: known)

        #expect(sightings.rows(known: known) == [zaal, x32, guest])
    }

    @Test func theLastUsedConsoleIsTheCardNotARow() {
        var sightings = ConsoleSightings()
        let known = KnownConsoles([fontein, zaal])
        sightings.scanned([fontein, zaal], known: known)

        #expect(sightings.rows(known: known) == [zaal])
    }
}

struct ConnectAddressTests {
    @Test func theScanAlsoAsksRememberedConsolesOffThisNetwork() {
        let hosts = Discovery.scanHosts(around: "192.168.1.23", known: [fontein.host, zaal.host])

        #expect(hosts.count == 254)
        #expect(hosts.last == zaal.host)
        #expect(hosts.filter { $0 == fontein.host }.count == 1)
    }

    @Test func withoutWiFiOnlyRememberedConsolesAreAsked() {
        #expect(Discovery.scanHosts(around: nil, known: [zaal.host]) == [zaal.host])
    }

    @Test func typingStartsFromThisPhonesNetwork() {
        #expect(Discovery.networkPrefix(of: "192.168.1.23") == "192.168.1.")
        #expect(Discovery.networkPrefix(of: nil) == "")
    }

    /// A Dutch decimal keypad only types commas.
    @Test(arguments: [("192,168,1,62", "192.168.1.62"), (" 10.10.0.20 ", "10.10.0.20")])
    func aTypedAddressIsCleanedUp(_ typed: String, _ host: String) {
        #expect(Discovery.typedAddress(typed) == host)
    }

    @Test(arguments: ["", "192.168.1.", "192.168.1", "m32.local", "192.168.1.300"])
    func aTypedNonAddressIsRefused(_ typed: String) {
        #expect(Discovery.typedAddress(typed) == nil)
    }
}
