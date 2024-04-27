import ComposableArchitecture
import SwiftUI

private let readMe = """
  이 애플리케이션은 Composable Architecture에서 SwiftUI의 refreshable API를 사용하는 방법을 보여줍니다. "-"와 "+" 버튼을 사용하여 수를 증가시키거나 감소시킨 후, 해당 숫자에 대한 사실을 요청하기 위해 아래로 당겨보세요.

  리듀서에 의해 시작된 효과를 나타내는 스토어의 .send 메소드에서 반환된 작업은 버릴 수 있습니다. 이 작업을 .finish 메소드를 사용하여 await할 수 있으며, 효과가 남아 있는 동안 일시 중지됩니다. 이 일시 중지는 데이터를 가져오고 있음을 SwiftUI에 알려 로딩 인디케이터가 계속 표시되도록 합니다.
  """

@Reducer
struct Refreshable {
  @ObservableState
  struct State: Equatable {
    var count = 0
    var fact: String?
  }

  enum Action {
    case cancelButtonTapped
    case decrementButtonTapped
    case factResponse(Result<String, Error>)
    case incrementButtonTapped
    case refresh
  }

  @Dependency(\.factClient) var factClient
  private enum CancelID { case factRequest }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .cancelButtonTapped:
        return .cancel(id: CancelID.factRequest)

      case .decrementButtonTapped:
        state.count -= 1
        return .none

      case let .factResponse(.success(fact)):
        state.fact = fact
        return .none

      case .factResponse(.failure):
        // NB: This is where you could do some error handling.
        return .none

      case .incrementButtonTapped:
        state.count += 1
        return .none

      case .refresh:
        state.fact = nil
        return .run { [count = state.count] send in
          await send(
            .factResponse(Result { try await self.factClient.fetch(count) }),
            animation: .default
          )
        }
        .cancellable(id: CancelID.factRequest)
      }
    }
  }
}

struct RefreshableView: View {
  let store: StoreOf<Refreshable>
  @State var isLoading = false

  var body: some View {
    List {
      Section {
        AboutView(readMe: readMe)
      }

      HStack {
        Button {
          store.send(.decrementButtonTapped)
        } label: {
          Image(systemName: "minus")
        }

        Text("\(store.count)")
          .monospacedDigit()

        Button {
          store.send(.incrementButtonTapped)
        } label: {
          Image(systemName: "plus")
        }
      }
      .frame(maxWidth: .infinity)
      .buttonStyle(.borderless)

      if let fact = store.fact {
        Text(fact)
          .bold()
      }
      if self.isLoading {
        Button("Cancel") {
          store.send(.cancelButtonTapped, animation: .default)
        }
      }
    }
    .refreshable {
      isLoading = true
      defer { isLoading = false }
      await store.send(.refresh).finish()
    }
  }
}

#Preview {
  RefreshableView(
    store: Store(initialState: Refreshable.State()) {
      Refreshable()
    }
  )
}
