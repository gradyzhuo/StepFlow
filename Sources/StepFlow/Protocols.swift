//
//  Protocols.swift
//  Procedure
//
//  Created by Grady Zhuo on 18/12/2016.
//  Copyright © 2016 Grady Zhuo. All rights reserved.
//

import Foundation

//MARK: - Protocols of Intent

public protocol Intent {
    var command: String { get }
    var value: Any? { get }
    
    init(command: String, value: Any?)
}


//MARK: - Protocols of Step

public protocol Identitiable {
    var identifier: String { get }
}

public protocol Flowable {
    /**
     (readonly)
     */
    var previous: Step? { set get }
    var next: Step? { set get }
    
    var last:Step { get }
    
    mutating func `continue`<T: Step>(with step:T, asLast: Bool)->T
}


public protocol Step {
    
    var name: String { set get }
    
    func run(with intents: Intents) async throws ->Intents
}

extension Step {
    
//    public var last:Step{
//        var nextStep: Step = self
//
//        while let next = nextStep.next {
//            nextStep = next
//        }
//        return nextStep
//    }
    
//    /**
//     設定接續的step，預設會串連在 last step 後面.
//     - parameters:
//         - with: the next step
//         - asLast: to be a next step after last step
//     */
//    @discardableResult
//    public func `continue`<T>(with step:T, asLast: Bool = true)->T where T : Step {
//        var last = asLast ? self.last : self
//        last.next = step
//        return step
//    }
    public func run(with inputs: Intent...) async throws ->Intents {
        return try await self.run(with: Intents(array: inputs))
    }
}

//MARK: - protocol Propagatable

public protocol Workable{
    var duties: [Duty] { get }
    
//    init(duties: [Duty])
//    func run(with intents: Intents, direction: Duty.PropagationDirection)
}

//MARK: - Shareable

//let k = UnsafeMutableRawPointer.allocate(byteCount: 0, alignment: 0)
//public protocol Shareable : Copyable, Identitiable{
//
//}

//private var instances:[String:Shareable] = [:]
//
//extension Shareable {
//
//    public static func shared(forKey key: String)->Self?{
//        return instances[key]?.copy
//    }
//
//    public func share()->String{
//        self.share(forKey: identifier)
//        return identifier
//    }
//
//    public func share(forKey key:String){
//        Self.instances[key] = copy
//    }
//}
