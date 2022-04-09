//
//  Intents.swift
//  Procedure
//
//  Created by Grady Zhuo on 2017/9/2.
//  Copyright © 2017年 Grady Zhuo. All rights reserved.
//

import Foundation

public struct Intents {
    public typealias IntentType = Intent
    internal var storage: [String: IntentType] = [:]
    
    public var commands: [String] {
        return storage.keys.map{ $0 }
    }
    
    public var count:Int{
        return storage.count
    }
    
    public mutating func add(intent: IntentType?) throws {
        
        guard let intent = intent else{
            throw StepFlow.Error.OperationNotPermitted(reason: "An intent to add into intents(\(withUnsafePointer(to: &self, { $0 }))) is nil.")
        }
        storage[intent.command] = intent
    }
    
    public mutating func add(intents: [IntentType]) throws {
        for intent in intents {
            try self.add(intent: intent)
        }
    }
    
    public mutating func add(intents: Intents) throws {
        for (_, intent) in intents.storage{
            try self.add(intent: intent)
        }
    }
    
    public mutating func remove(for name: String)->IntentType!{
        return storage.removeValue(forKey: name)
    }
    
    public mutating func remove(intent: IntentType){
        storage.removeValue(forKey: intent.command)
    }
    
    public func contains(command: String)->Bool {
        return commands.contains(command)
    }
    
    public func contains(intent: SimpleIntent)->Bool {
        return commands.contains(intent.command)
    }
    
    public func intent(for name: String)-> IntentType? {
        return storage[name]
    }
    
    //MARK: - init
    
    public static var empty: Intents {
        return []
    }
    
    public init(array intents: [IntentType]){
        do{
            try self.add(intents: intents)
        }catch{
            print(error)
        }
    }
    
    public init(intents: Intents){
        do{
            try self.add(intents: intents)
        }catch{
            print(error)
        }
    }
    
    //MARK: - subscript
    
    public subscript<T>(name: String)->T? {
        set{
            let intent = SimpleIntent(command: name, value: newValue)
            do{
                try self.add(intent: intent)
            }catch{
                print(error)
            }
        }
        
        get{
            return intent(for: name)?.value as? T
        }
        
    }
}

extension Intents : ExpressibleByArrayLiteral{
    public typealias Element = IntentType
    
    
    public init(arrayLiteral elements: Element...) {
        self = Intents(array: elements)
    }
    
}

extension Intents : ExpressibleByDictionaryLiteral{
    public typealias Key = String
    public typealias Value = Any
    
    public init(dictionaryLiteral elements: (Key, Value)...) {
        for (key, value) in elements {
            let intent = SimpleIntent(command: key, value: value)
            do{
                try self.add(intent: intent)
            }catch{
                print(error)
            }
            
        }
    }
    
}

public func +(lhs: Intents, rhs: Intents)->Intents{
    var results = Intents.empty
    do{
        try results.add(intents: lhs)
        try results.add(intents: rhs)
    }catch{
        print(error)
    }
    return results
}

public func +(lhs: Intents, rhs: Intents.IntentType)->Intents{
    var results = Intents.empty
    do{
        try results.add(intents: lhs)
        try results.add(intent: rhs)
    }catch{
        print(error)
    }
    return results
}

public func +(lhs: Intents, rhs: String)->Intents{
    var results = Intents.empty
    do{
        try results.add(intents: lhs)
        try results.add(intent: SimpleIntent(command: rhs))
    }catch{
        print(error)
    }
    return results
}
