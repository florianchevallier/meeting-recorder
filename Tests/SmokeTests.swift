import Testing

@Suite("Smoke")
struct SmokeTests {
    @Test("sanity")
    func sanity() {
        #expect(1 + 1 == 2)
    }
}
