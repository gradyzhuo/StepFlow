//
//  File.swift
//  
//
//  Created by 卓俊諺 on 2022/4/9.
//

import Foundation

class MapStep<Value>: Step, Propagatable{
    var duties: [Duty] = []
    var operation: Duty.Operation
    
    var name: String = ""
    var previous: Step?
    var next: Step?
    
    var wrappedCommand: String
    var unwrappedCommand: String
    var queue: DispatchQueue
    
    init(wrapped wrappedCommand: String, unwrapped unwrappedCommand: String, do operation: @escaping Duty.Operation){
        self.wrappedCommand = wrappedCommand
        self.unwrappedCommand = unwrappedCommand
        self.operation = operation
        self.queue = DispatchQueue.global()
    }
    
    func run(with intents: Intents) {
        self.run(with: intents, direction: .forward)
    }
    
    func run(with intents: Intents, direction: Duty.PropagationDirection) {
        guard let values:[Value] = intents[wrappedCommand] else{
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
                    $0 + $1
                }
                
                print("outputs:", outputs)
            }
            
        }
        
        self.queue.sync(execute: workItem)
        
    }
    
}
