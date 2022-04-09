//
//  File.swift
//  
//
//  Created by 卓俊諺 on 2022/4/9.
//

import Foundation

open class MapStep<Value>: Step{
    
//    public var duties: [Duty] = []
//    public typealias Value = [[String:String]]
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
    
    
    public func run(with inputs: Intents) async throws -> Intents {
        guard let values:[Value] = inputs[wrappedCommand] else{
            return Intents.empty
        }
        
        let duties = values.map{ _ in Duty(do: self.operation) }
        return try await withThrowingTaskGroup(of: Intents.self, returning: [Intents].self, body: { group in
            for (offset, duty) in duties.enumerated(){
                group.addTask {
                    let value = values[offset]
                    let inputs = inputs + Intents(arrayLiteral: SimpleIntent(command: self.wrappedCommand, value: value))
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
            for command in $1.commands{
                guard let value:Any = $1[command]?.value else{
                    return results
                }
                if let values:[Any] = $0[self.unwrappedCommand]{
                    results[self.unwrappedCommand] = values + [value]
                }else{
                    results[command] = [value]
                }
            }
            return results
        }
    }

}

extension MapStep where Value == [String:String]{
    public func run(with inputs: Intents = []) async throws ->Intents{
        guard let values:[Value] = inputs[wrappedCommand] else{
            return Intents.empty
        }
        
        let duties = values.map{ _ in Duty(do: self.operation) }
        return try await withThrowingTaskGroup(of: Intents.self, returning: [Intents].self, body: { group in
            for (offset, duty) in duties.enumerated(){
                group.addTask {
                    let value = values[offset]
                    let inputs = inputs + Intents(array: value.reduce([Intent]()) {
                        $0 + [SimpleIntent(command: $1.key, value: $1.value)]
                    })
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
            for command in $1.commands{
                guard let value:Any = $1[command]?.value else{
                    return results
                }
                if let values:[Any] = $0[self.unwrappedCommand]{
                    results[self.unwrappedCommand] = values + [value]
                }else{
                    results[command] = [value]
                }
            }
            return results
        }
        
    }
}

