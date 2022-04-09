//
//  Action.swift
//  Procedure
//
//  Created by Grady Zhuo on 22/11/2016.
//  Copyright © 2016 Grady Zhuo. All rights reserved.
//

import Foundation

public typealias InputIntents = Intents

extension Duty {
    
    public enum PropagationDirection : Int{
        case forward
        case backward
    }
    
//    //MARK: typealias defines
//    public enum Result {
//        case succeedWith(outcome: Intent?)
//        case failureWith(error: Procedure.Error?)
//
//        public var outcomes: Intents {
//
//            var o: Intent?
//            switch self {
//            case .succeedWith(let outcome):
//                o = outcome
//            case .failureWith(let error):
//                o = error
//            }
//
//            guard let outcome = o else {
//                return []
//            }
//
//            return [outcome]
//        }
//
//        public static var succeed: Result {
//            return .succeedWith(outcome: nil)
//        }
//
//        public static var failure: Result {
//            return .failureWith(error: Procedure.Error(name: "Error", reason: "Unknown reason", userInfo: nil))
//        }
//
//    }
}

open class Duty : Identitiable, Hashable, CustomStringConvertible {
    
    public typealias Operation = (InputIntents, CheckedContinuation<Intents?, Error>)->Void
    public internal(set) var identifier: String
    public internal(set) var operation: Operation
    public let qos: DispatchQoS
    
    public internal(set) var propagationDirection: PropagationDirection = .forward
    
    public var isCancelled:Bool{
        return self.runningItem?.isCancelled ?? false
    }
    
    internal var runningItem: DispatchWorkItem?
    
    public func hash(into hasher: inout Hasher) {
        self.identifier.hash(into: &hasher)
    }
    
    public init(identifier:String = Utils.Generator.identifier(), propagationDirection direction: PropagationDirection = .forward, qos: DispatchQoS = .default, do action: @escaping Operation){
        self.identifier = identifier
        self.operation = action
        self.propagationDirection = direction
        self.qos = qos
    }
    
    public func run(with inputs: InputIntents, inQueue queue: DispatchQueue = .main) async throws -> Intents{
        
        let outcome:Intents? = try await withCheckedThrowingContinuation{ continuation in
            
            let workItem = DispatchWorkItem(qos: self.qos, flags: .assignCurrentContext) {
                self.operation(inputs, continuation)
            }
            
            self.runningItem = workItem
            queue.async(execute: workItem)
        }
    
        return outcome ?? Intents.empty
        
    }
    
    
    public func cancel(){
        guard let runningItem = runningItem else {
            return
        }
        
        if !runningItem.isCancelled {
            runningItem.cancel()
        }
        
    }
    
    public var description: String{
        return "Task(\(identifier)): \(String(describing: operation))"
    }
    
    deinit {
        print("deinit action : \(identifier)")
    }
}

public func ==(lhs: Duty, rhs: Duty)->Bool{
    return lhs.identifier == rhs.identifier
}

extension Duty : Copyable {
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let taskCopy = self.operation
        return Duty(identifier: identifier, do: taskCopy)
    }
    
    
}
