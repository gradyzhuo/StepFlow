//
//  Step.swift
//  Procedure
//
//  Created by Grady Zhuo on 22/11/2016.
//  Copyright © 2016 Grady Zhuo. All rights reserved.
//

import Foundation

public typealias OutputIntents = Intents
open class SimpleStep : Step, Propagatable, Flowable, CustomStringConvertible, Identitiable {
    public internal(set) var duties: [Duty]
    
    public var previous: Step?
    
    public typealias IntentType = SimpleIntent
    
    public var identifier: String{
        return queue.label
    }
    public lazy var name: String = self.identifier
    
    public var next: Step?{
        didSet{
            let current = self
            next.map{ nextStep in
                var nextStep = nextStep
                nextStep.previous = current
            }
        }
    }
    
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
    
    public func run(with inputs: Intent...){
        self.run(with: Intents(array: inputs))
    }
    
    public func run(with inputs: Intents = []){
        self.run(with: inputs, direction: .forward)
    }

    public func run(with inputs: Intents, direction: Duty.PropagationDirection){
        let workItem = DispatchWorkItem {
            Task{
                let outputs = try await withThrowingTaskGroup(of: Intents.self, returning: [Intents].self, body: { group in
                    for duty in self.duties.filter({ $0.propagationDirection == direction }) {
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
                self.actionsDidFinish(original: inputs, outputs: outputs)
            }
        }
        self.queue.sync(execute: workItem)
    }
    
    public func cancel(){
        for act in duties {
            act.cancel()
        }
    }
    
    internal func actionsDidFinish(original inputs: Intents, outputs: Intents){
        
        let outputs = inputs + outputs
        
        let control = flowHandler(outputs)
        switch control {
        case .repeat:
            run(with: outputs)
        case .cancel:
            print("cancelled")
        case .finish:
            print("finished")
        case .nextWith(let filter):
            goNext(with: filter(outputs))
        case .previousWith(let filter):
            goBack(with: filter(outputs))
        case .jumpTo(let other, let filter):
            jump(to: other, with: filter(outputs))
        }
        
    }
    
    
    public func goNext(with intents: Intents){
        if let next = next as? Propagatable {
            next.run(with: intents, direction: .forward)
        }else{
            next?.run(with: intents)
        }
        
    }
    
    public func goBack(with intents: Intents){
        
        if let previous = previous as? Propagatable {
            previous.run(with: intents, direction: .backward)
        }else{
            previous?.run(with: intents)
        }
    }
    
    public func jump(to step: Step, with intents: Intents){
        if let step = step as? Propagatable {
            step.run(with: intents, direction: .forward)
        }else{
            step.run(with: intents)
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

