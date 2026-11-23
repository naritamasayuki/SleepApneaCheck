import XCTest
@testable import SleepApneaCheck

final class AmazonAffiliateServiceTests: XCTestCase {

    func testJapanLocaleGeneratesAmazonCoJpWithAssociateTag() {
        let jpLocale = Locale(identifier: "ja_JP")
        XCTAssertTrue(AmazonAffiliateService.isJapanLocale(jpLocale))

        for good in SleepCareGood.allCases {
            let url = AmazonAffiliateService.searchURL(for: good, locale: jpLocale)
            XCTAssertNotNil(url)
            XCTAssertEqual(url?.host, "www.amazon.co.jp")
            XCTAssertEqual(url?.path, "/s")

            let items = URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let tag = items.first(where: { $0.name == "tag" })?.value
            let keyword = items.first(where: { $0.name == "k" })?.value
            XCTAssertEqual(tag, "shirokumacamp-22")
            XCTAssertFalse((keyword ?? "").isEmpty)
        }
    }

    func testOverseasLocaleGeneratesAmazonComWithoutJapanTag() {
        let usLocale = Locale(identifier: "en_US")
        XCTAssertFalse(AmazonAffiliateService.isJapanLocale(usLocale))

        let url = AmazonAffiliateService.searchURL(for: .sideSleeperPillow, locale: usLocale)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "www.amazon.com")

        let items = URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertNil(items.first(where: { $0.name == "tag" }))
        XCTAssertEqual(items.first(where: { $0.name == "k" })?.value, "anti snoring side sleeper pillow")
    }
}
