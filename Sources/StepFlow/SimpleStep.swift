//
//  Step.swift
//  Procedure
//
//  Created by Grady Zhuo on 22/11/2016.
//  Copyright © 2016 Grady Zhuo. All rights reserved.
//

import Foundation

public typealias OutputIntents = Intents
open class SimpleStep : Step, CustomStringConvertible, Workable, Identitiable {
    public internal(set) var duties: [Duty]
    
    public typealias IntentType = SimpleIntent
    
    public var identifier: String{
        return queue.label
    }
    public lazy var name: String = self.identifier
    
    internal let autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency
    internal let attributes: DispatchQueue.Attributes
    internal let qos: DispatchQoS
    fileprivate var runningItem: DispatchWorkItem?
    public internal(set) var queue: DispatchQueue
    
    internal var flowHandler:(OutputIntents)->FlowControl = { _ in
        return .next
    }
    
    public convenience init(direction: Duty.PropagationDirection = .forward, do action: @escaping Duty.Operation){
        let duty = Duty(propagationDirection: direction, do: action)
        self.init(duty: duty)
    }
    
    internal init(duties:[Duty], attributes: DispatchQueue.Attributes = .concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = .inherit, qos: DispatchQoS = .default, other: SimpleStep? = nil){
        self.autoreleaseFrequency = autoreleaseFrequency
        self.attributes = attributes
        self.qos = qos
        
        self.queue = DispatchQueue(label: Utils.Generator.identifier(), qos: qos, attributes: attributes, autoreleaseFrequency: autoreleaseFrequency, target: other?.queue)
        
        self.duties = duties
        
    }
    
    public convenience init(duty: Duty) {
        self.init(duties: [duty])
    }
    
    public convenience init(){
        self.init(duties: [])
    }
    
    public required convenience init(duties: [Duty]) {
        self.init(duties: duties, attributes: .concurrent, autoreleaseFrequency: .inherit, qos: .userInteractive, other: nil)
    }
    
    public func setControl(_ flowControl: @escaping (OutputIntents)->FlowControl){
        flowHandler = flowControl
    }
    
    public func run(with inputs: Intents = []) async throws ->Intents{
        return try await withThrowingTaskGroup(of: Intents.self, returning: [Intents].self, body: { group in
            for duty in self.duties {
                group.addTask {
                    try await duty.run(with: inputs, inQueue: self.queue)
                }
            }
            
            var outcomes: [Intents] = []
            for try await result in group {
                outcomes.append(result)
            }
            return outcomes
        }).reduce(Intents.empty){
            $0 + $1
        }
    }

    
    public func cancel(){
        for act in duties {
            act.cancel()
        }
    }
    
    public var description: String{
        
        let actionDescriptions = duties.reduce("") { (result, action) -> String in
            return result.count == 0 ? "<\(action)>" : "\(result)\n<\(action)>"
        }
        
        return "\(type(of: self))(\(identifier)): [\(actionDescriptions)]"
    }
    
    deinit {
        print("deinit Step : \(identifier)")
    }
}

extension SimpleStep : Hashable {
    
    public func hash(into hasher: inout Hasher) {
        identifier.hash(into: &hasher)
    }
}

public func ==<T:Hashable>(lhs: T, rhs: T)->Bool{
    return lhs.hashValue == rhs.hashValue
}

//extension SimpleStep : Copyable{
//    
//    public func copy(with zone: NSZone? = nil) -> Any {
//        let dutiesCopy = self.duties.map{ $0.copy }
//        let aCopy = SimpleStep(duties: dutiesCopy, attributes: attributes, autoreleaseFrequency: autoreleaseFrequency, qos: qos)
//        aCopy.flowHandler = flowHandler
//        return aCopy
//    }
//}

extension SimpleStep {

    public func add(duties: [Duty]) throws {
        guard self.runningItem == nil else{
            throw StepFlow.Error.OperationNotPermitted(reason: "All operation of duties was denied when step is running.")
        }
        self.duties.append(contentsOf: duties)
    }
    
    public func add(_ duty: Duty) throws {
        self.duties.append(duty)
    }
    
    public func add(_ operation: @escaping Duty.Operation) throws {
        let duty = Duty(do: operation)
        self.duties.append(duty)
    }
    
    public func remove(duty: Duty) throws {
        self.duties.removeAll{ $0 == duty }
    }
}

