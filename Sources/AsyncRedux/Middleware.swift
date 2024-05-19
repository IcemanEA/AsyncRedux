//
//  Middleware.swift
//  AsyncRedux
//
//  Created by Egor Ledkov on 16.05.2024.
//

import Foundation

/// Протокол для внедрения Middlewares в Redux flow.
public protocol Middleware {
	associatedtype Action
	
	/// Функция, которая отслеживает нужные Actions и реагирует на них.
	/// - Parameter action: Действие.
	/// - Returns: Следующее действие, если вернулся nil, то цепочка останавливает свою работу.
	func callAsFunction(action: Action) async -> Action?
}

/// Стандартная реализация протокола (Обертка), для возможности описать абстрактный класс Store.
public struct AnyMiddleware<Action>: Middleware {
	private let wrappedMiddleware: (Action) async -> Action?
	
	public init<M: Middleware>(_ middleware: M) where M.Action == Action {
		self.wrappedMiddleware = middleware.callAsFunction(action:)
	}
	
	/// Функция, которая отслеживает нужные Actions и реагирует на них.
	/// - Parameter action: Действие.
	/// - Returns: Следующее действие, если вернулся nil, то цепочка останавливает свою работу.
	public func callAsFunction(action: Action) async -> Action? {
		return await wrappedMiddleware(action)
	}
}

// MARK: - eraseToAnyMiddleware

extension Middleware {
	
	/// Для обратного возврата к дефолтному типу.
	public func eraseToAnyMiddleware() -> AnyMiddleware<Action> {
		return self as? AnyMiddleware<Action> ?? AnyMiddleware(self)
	}
}

// MARK: - EchoMiddleware

/// Структура - заглушка Middleware, которая просто пропускает действие через себя, ничего не делая.
public struct EchoMiddleware<Action>: Middleware {
	
	/// Функция, которая отслеживает нужные Actions и реагирует на них.
	/// - Parameter action: Действие.
	/// - Returns: Возвращает тоже действие, что и поступало на вход.
	public func callAsFunction(action: Action) async -> Action? {
		return action
	}
}

// MARK: - MiddlewarePipeline

/// Прослойка для объединения в массив всех Middleware для последовательной их обработки
public struct MiddlewarePipeline<Action>: Middleware {
	
	private let middleware: [AnyMiddleware<Action>]
	
	public init(_ middleware: AnyMiddleware<Action>...) {
		self.middleware = middleware
	}
	
	public init(_ middleware: [AnyMiddleware<Action>]) {
		self.middleware = middleware
	}
	
	public func callAsFunction(action: Action) async -> Action? {
		var currentAction: Action = action
		
		for m in middleware {
			guard let newAction = await m(action: currentAction) else { return nil }
			currentAction = newAction
		}
		
		return currentAction
	}
}

// MARK: - MiddlewareBuilder

/// Добавляем возможность создавать список Middleware с помощью View
/// (можно юзать условные операторы, а также массивы)
@resultBuilder public struct MiddlewareBuilder<Action> {
	public static func buildArray(
		_ components: [MiddlewarePipeline<Action>]
	) -> AnyMiddleware<Action> {
		MiddlewarePipeline(components.map { $0.eraseToAnyMiddleware() })
			.eraseToAnyMiddleware()
	}
	
	public static func buildBlock(
		_ components: AnyMiddleware<Action>...
	) -> MiddlewarePipeline<Action> {
		.init(components)
	}
	
	public static func buildEither<M: Middleware>(
		first component: M
	) -> AnyMiddleware<Action> where M.Action == Action {
		component.eraseToAnyMiddleware()
	}
	
	public static func buildEither<M: Middleware>(
		second component: M
	) -> AnyMiddleware<Action> where M.Action == Action {
		component.eraseToAnyMiddleware()
	}
	
	public static func buildExpression<M: Middleware>(
		_ expression: M
	) -> AnyMiddleware<Action> where M.Action == Action {
		expression.eraseToAnyMiddleware()
	}
	
	public static func buildFinalResult<M: Middleware>(
		_ component: M
	) -> AnyMiddleware<Action> where M.Action == Action {
		component.eraseToAnyMiddleware()
	}
	
	public static func buildOptional(
		_ component: MiddlewarePipeline<Action>?
	) -> AnyMiddleware<Action> {
		guard let component = component else {
			return EchoMiddleware<Action>().eraseToAnyMiddleware()
		}
		
		return component.eraseToAnyMiddleware()
	}
}
