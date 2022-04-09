//
//  File.swift
//  
//
//  Created by 卓俊諺 on 2022/4/9.
//

import Foundation

open class MapStep<Value, Output>: Step, Propagatable{
    public var duties: [Duty] = []
    public var operation: Duty.Operation
    
    public var name: String = ""
    public var previous: Step?
    public var next: Step?
    
    public var wrappedCommand: String
    public var unwrappedCommand: String
    public var queue: DispatchQueue
    
    public init(wrapped wrappedCommand: String, unwrapped unwrappedCommand: String, do operation: @escaping Duty.Operation){
        self.wrappedCommand = wrappedCommand
        self.unwrappedCommand = unwrappedCommand
        self.operation = operation
        self.queue = DispatchQueue.global()
    }
    
    public func run(with intents: Intents) {
        self.run(with: intents, direction: .forward)
    }
    
    public func run(with intents: Intents, direction: Duty.PropagationDirection) {
        guard let values:[Value] = intents[wrappedCommand] else{
            print("XXX")
            return
        }
        
        self.duties = values.map{ _ in Duty(do: self.operation) }
        
        
        let workItem = DispatchWorkItem {
            Task{
                let outputs = try await withThrowingTaskGroup(of: Intents.self, returning: [Intents].self, body: { group in
                    for (offset, duty) in self.duties.enumerated(){
                        group.addTask {
                            let value = values[offset]
                            var inputs = Intents(intents: intents)
                            inputs[self.unwrappedCommand] = value
                            return try await duty.run(with: inputs, inQueue: self.queue)
                        }
                    }
                    
                    var outcomes: [Intents] = []
                    for try await result in group {
                        outcomes.append(result)
                    }
                    return outcomes
                }).reduce(Intents.empty){
                    var results = $0
                    print("results:", results)
                    for command in $1.commands{
                        if let intents:[Intent] = $1[command]{
                            results[command] = intents + [$1[command]]
                        }else{
                            results[command] = [$1[command]]
                        }
                    }
                    return results
                }
                
                print("outputs:", outputs)
            }
            
        }
        
        self.queue.sync(execute: workItem)
        
    }
    
}
