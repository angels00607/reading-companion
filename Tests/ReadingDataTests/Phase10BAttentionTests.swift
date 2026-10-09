import XCTest
import ReadingDomain
@testable import ReadingData

final class Phase10BAttentionTests: XCTestCase {
    private func store(_ path:String=":memory:",owner:UUID=UUID()) throws -> LocalStore { try LocalStore(path:path,ownerID:owner) }

    func testCreateDeduplicateFilterResolveAndRestart() throws {
        let s=try store(), entity=UUID(), action=UUID()
        let draft=AttentionDraft(category:.import,priority:.required,entityID:entity,actionID:action,reason:"candidate",title:"Review imported data",detail:"Choose how this row maps.",source:"StoryGraph CSV")
        let first=try s.createAttention(draft), duplicate=try s.createAttention(draft)
        XCTAssertEqual(first.id,duplicate.id)
        XCTAssertEqual(try s.unresolvedAttentionCount(),1)
        XCTAssertEqual(try s.unresolvedAttention(filter:.all).map(\.category),[.import])
        XCTAssertTrue(try s.unresolvedAttention(filter:.books).isEmpty,"Import is intentionally available through All only")
        try s.resolveAttention(id:first.id)
        XCTAssertEqual(try s.unresolvedAttentionCount(),0)
        _ = try s.createAttention(draft)
        XCTAssertEqual(try s.unresolvedAttentionCount(),0,"Duplicate evidence must not silently reopen a user decision")
        try s.restartAttention(id:first.id)
        XCTAssertEqual(try s.unresolvedAttentionCount(),1)
    }

    func testOwnerScopeAndPersistence() throws {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".sqlite"),owner=UUID(),entity=UUID()
        defer { try? FileManager.default.removeItem(at:url) }
        let first=try store(url.path,owner:owner)
        try first.createAttention(.init(category:.books,entityID:entity,reason:"metadata",title:"Review book information",detail:"A title changed."))
        XCTAssertEqual(try store(url.path,owner:owner).unresolvedAttentionCount(),1)
        XCTAssertEqual(try store(url.path,owner:UUID()).unresolvedAttentionCount(),0)
    }

    func testBookProposalCreatesAndDecisionResolvesAttentionWithoutOverwritingKeepChoice() throws {
        let s=try store()
        let book=try s.add(work:.init(provider:"manual",reference:"one",title:"Saved title",author:"Saved author"),choice:.addAnyway)
        try s.reviewProvider(bookID:book,work:.init(provider:"catalogue",reference:"two",title:"Proposed title",author:"Saved author"))
        let item=try XCTUnwrap(s.unresolvedAttention(filter:.books).first)
        XCTAssertEqual(item.entityID,book);XCTAssertEqual(item.source,"catalogue two")
        let proposal=try XCTUnwrap(s.proposals(bookID:book).first)
        try s.decide(proposalID:proposal.id,accept:false)
        XCTAssertEqual(try s.record(id:book).book.title,"Saved title")
        XCTAssertTrue(try s.unresolvedAttention(filter:.books).isEmpty)
    }

    func testSeriesProposalCreatesOneAttentionAndKeepPreservesUserValue() throws {
        let s=try store(),owner=s.ownerID,series=ReadingSeries(ownerID:owner,name:"Saved Series")
        try s.saveSeries(series,entries:[])
        try s.propose(seriesID:series.id,field:"Series name",current:"Saved Series",proposed:"Suggested Series",source:"Catalogue",evidenceFingerprint:"series-name-v1")
        try s.propose(seriesID:series.id,field:"Series name",current:"Saved Series",proposed:"Suggested Series",source:"Catalogue",evidenceFingerprint:"series-name-v1")
        XCTAssertEqual(try s.unresolvedAttention(filter:.series).count,1)
        let proposal=try XCTUnwrap(s.proposals(seriesID:series.id).first)
        try s.rejectProposal(id:proposal.id)
        XCTAssertEqual(try s.seriesDetail(id:series.id).series.name,"Saved Series")
        XCTAssertTrue(try s.unresolvedAttention(filter:.series).isEmpty)
    }
}
