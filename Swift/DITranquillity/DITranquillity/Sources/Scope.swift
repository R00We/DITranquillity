//
//  Scope.swift
//  DITranquillity
//
//  Created by Alexander Ivlev on 10/06/16.
//  Copyright © 2016 Alexander Ivlev. All rights reserved.
//

public protocol ScopeProtocol {
  func resolve<T>() throws -> T
  func resolve<T>(_: T.Type) throws -> T
  
  func newLifeTimeScope() throws -> ScopeProtocol
  func newLifeTimeScope(name: String) throws -> ScopeProtocol
}

prefix operator *!{}
public prefix func *!<T>(scope: ScopeProtocol) -> T {
  return try! scope.resolve()
}

prefix operator *{}
public prefix func *<T>(scope: ScopeProtocol) throws -> T {
  return try scope.resolve()
}

internal class Scope : ScopeProtocol {
  internal init(registeredTypes: RTypeContainerReadonly, parent: ScopeProtocol? = nil, name: String = "") {
    self.registeredTypes = registeredTypes
    self.parent = parent
    self.name = name
  }
  
  func resolve<T>() throws -> T {
    guard let rType = registeredTypes[T.self] else {
      throw Error.TypeNoRegister(typeName: String(T.self))
    }
    
    return try resolveUseRType(rType)
  }
  
  internal func resolve<T>(_: T.Type) throws -> T {
    return try resolve()
  }
  
  internal func newLifeTimeScope() throws -> ScopeProtocol {
    return Scope(registeredTypes: registeredTypes, parent: self)
  }
  
  internal func newLifeTimeScope(name: String = "") throws -> ScopeProtocol {
    return Scope(registeredTypes: registeredTypes, parent: self, name: name)
  }
  
  //Private
  internal func resolveUseRType<T>(rType: RTypeReader) throws -> T {
    switch rType.lifeTime {
    case .Single:
      return try resolveSingle(rType)
    case let .PerMatchingScope(name):
      return try resolvePerMatchingScope(rType, name)
    case .PerScope:
      return try resolvePerScope(rType)
    case .PerDependency:
      return try resolvePerDependency(rType)
    }
  }
  
  internal func resolveSingle<T>(rType: RTypeReader) throws -> T {
    let key = String(T.self)
    
    if let obj = Scope.singleObjects[key] {
      return obj as! T
    }
    
    let obj: T = try resolvePerDependency(rType)
    Scope.singleObjects[key] = obj
    return obj
  }
  
  internal func resolvePerMatchingScope<T>(rType: RTypeReader, _ name: String) throws -> T {
    if name == self.name {
      return try resolvePerScope(rType)
    }
    
    guard let scopeParent = parent else {
      throw Error.ScopeNotFound(scopeName: name)
    }
    
    return try scopeParent.resolve()
  }
  
  internal func resolvePerScope<T>(rType: RTypeReader) throws -> T {
    let key = String(T.self)
    
    if let obj = objects[key] {
      return obj as! T
    }
    
    let obj: T = try resolvePerDependency(rType)
    objects[key] = obj
    return obj
  }
  
  internal func resolvePerDependency<T>(rType: RTypeReader) throws -> T {
    let obj = rType.initType(self)
    guard let result = obj as? T else {
      throw Error.TypeIncorrect(askableType: String(T.self), realType: String(obj.self))
    }
    
    return result
  }
  
  private static var singleObjects: [String: Any] = [:]
  
  private var objects: [String: Any] = [:]
  private let name: String
  private let registeredTypes: RTypeContainerReadonly
  private let parent: ScopeProtocol?
}