//
//  Store.swift
//  AsyncRedux
//
//  Created by Egor Ledkov on 15.05.2024.
//

import Foundation

/// Протокол для соблюдения обязательного правила State хранилища - должно уметь
/// инициализироваться без сторонних зависимостей
public protocol State {
	init()
}

/// Актор Store для обработки входящих событий , и обработки текущего  стейта
public actor Store<S: State, Action>: ObservableObject {
	public typealias Reducer = (inout S, Action) -> ()
	
	@MainActor @Published public private(set) var state: S = .init()
	
	private let middleware: AnyMiddleware<Action>
	private let reducer: Reducer
	
	public init<M: Middleware>(
		reducer: @escaping Reducer,
		@MiddlewareBuilder<Action> middleware: () -> M
	) where M.Action == Action {
		self.reducer = reducer
		self.middleware = middleware().eraseToAnyMiddleware()
	}
	
	/// Простая инициализация с дефолтным редъюсером и без дополнительных Middleware
	public init(reducer: @escaping Reducer) {
		self.init(
			reducer: reducer,
			middleware: {
				EchoMiddleware<Action>()
			}
		)
	}
	
	/// Запуск асинхронного события в работу флоу
	/// - Parameter action: Новое входящее событие
	public func dispatch(action: Action) async {
		guard let newAction = await middleware(action: action) else { return }
		
		await MainActor.run {
			reducer(&state, newAction)
		}
	}
}

extension Store {
	/// Выполнить действие с помощью метода
	public func dispatch(_ factory: () async -> Action) async {
		await self.dispatch(action: await factory())
	}
}

extension Store {
	/// Выполнить асинхронную очередь действий
	public func dispatch<Seq: AsyncSequence>(
		sequence: Seq
	) async throws where Seq.Element == Action {
		for try await action in sequence {
			await dispatch(action: action)
		}
	}
}
