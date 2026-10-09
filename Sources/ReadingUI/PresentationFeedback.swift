import SwiftUI
import ReadingDomain

public enum CelebrationKind:String,Equatable,Sendable { case bookCompleted,achievementUnlocked,levelUp }
public enum PresentationMotionStyle:Equatable,Sendable { case fade,fadeAndScale }
public enum PresentationMotionPolicy {
    public static func celebrationStyle(reduceMotion:Bool)->PresentationMotionStyle { reduceMotion ? .fade:.fadeAndScale }
    public static func celebrationDuration(reduceMotion:Bool)->Double { reduceMotion ? 0.18:0.24 }
}
public struct PresentationCelebration:Identifiable,Equatable,Sendable {
    public let id:String;public let kind:CelebrationKind;public let eyebrow:String;public let title:String;public let message:String;public let symbol:String
    public init(id:String,kind:CelebrationKind,eyebrow:String,title:String,message:String,symbol:String){self.id=id;self.kind=kind;self.eyebrow=eyebrow;self.title=title;self.message=message;self.symbol=symbol}
}
public struct CelebrationQueue:Equatable,Sendable {
    private(set) public var pending:[PresentationCelebration]=[]
    private var seen:Set<String>=[]
    public init(){}
    public var active:PresentationCelebration?{pending.first}
    @discardableResult public mutating func enqueue(_ value:PresentationCelebration)->Bool {
        guard seen.insert(value.id).inserted else{return false};pending.append(value);return true
    }
    public mutating func dismiss(){if !pending.isEmpty{pending.removeFirst()}}
}
public enum CelebrationFactory {
    public static func next(before:[XPAward],after:[XPAward])->PresentationCelebration? {
        let previous=Set(before.map(\.semanticKey)),added=after.filter{!previous.contains($0.semanticKey)}
        let oldLevel=GamificationBalance.level(totalXP:before.reduce(0){$0+$1.amount}),newLevel=GamificationBalance.level(totalXP:after.reduce(0){$0+$1.amount})
        if newLevel > oldLevel { return .init(id:"level:\(newLevel)",kind:.levelUp,eyebrow:"LEVEL UP",title:"Level \(newLevel)",message:"Your configured cosmetics are available. Every reading feature remains available.",symbol:"sparkles") }
        if let award=added.first(where:{$0.source == .achievement}) {
            let key=String(award.semanticKey.dropFirst("achievement:".count)),name=AchievementCatalog.all.first{$0.key == key}?.name ?? "Achievement"
            return .init(id:award.semanticKey,kind:.achievementUnlocked,eyebrow:"ACHIEVEMENT UNLOCKED",title:name,message:"+\(award.amount) XP awarded once.",symbol:"medal.fill")
        }
        if let award=added.first(where:{$0.source == .finishBook}) { return .init(id:award.semanticKey,kind:.bookCompleted,eyebrow:"BOOK COMPLETED",title:"A reading journey finished",message:"Your completion is saved and the Journal can be prepared when you are ready.",symbol:"book.closed.fill") }
        return nil
    }
}

public struct CelebrationOverlay:View {
    @EnvironmentObject private var model:BooksModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init(){}
    public var body:some View {
        if let event=model.activeCelebration {
            ZStack {
                Color.black.opacity(0.28).ignoresSafeArea().onTapGesture{model.dismissCelebration()}
                FeatureCelebration(eyebrow:event.eyebrow,title:event.title,message:event.message,symbol:event.symbol,dismiss:{model.dismissCelebration()}).padding(24)
            }.transition(PresentationMotionPolicy.celebrationStyle(reduceMotion:reduceMotion) == .fade ? .opacity:.opacity.combined(with:.scale(scale:0.98)))
                .animation(.easeOut(duration:PresentationMotionPolicy.celebrationDuration(reduceMotion:reduceMotion)),value:event.id)
                .sensoryFeedback(.success,trigger:event.id)
                .accessibilityAddTraits(.isModal)
        }
    }
}
