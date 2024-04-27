import ComposableArchitecture
import SwiftUI

private let readMe = """
  이 화면은 작은 기능을 가져와서 리듀서 빌더와 Scope 리듀서를 사용하여 더 큰 기능으로 구성하는 방법을 보여줍니다. \
  또한 스토어에 있는 scope 연산자를 사용합니다.

  이는 카운터 화면의 도메인을 재사용하고, 그것을 더 큰 도메인에 두 번 포함시킵니다.
  """

@Reducer
struct TwoCounters {
  @ObservableState
  struct State: Equatable {
    var counter1 = Counter.State()
    var counter2 = Counter.State()
  }

  enum Action {
    case counter1(Counter.Action)
    case counter2(Counter.Action)
  }

  var body: some Reducer<State, Action> {
    Scope(state: \.counter1, action: \.counter1) {
      Counter()
    }
    Scope(state: \.counter2, action: \.counter2) {
      Counter()
    }
  }
}

struct TwoCountersView: View {
  let store: StoreOf<TwoCounters>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      HStack {
        Text("Counter 1")
        Spacer()
        CounterView(store: store.scope(state: \.counter1, action: \.counter1))
      }

      HStack {
        Text("Counter 2")
        Spacer()
        CounterView(store: store.scope(state: \.counter2, action: \.counter2))
      }
    }
    .buttonStyle(.borderless)
    .navigationTitle("Two counters demo")
  }
}

#Preview {
  NavigationStack {
    TwoCountersView(
      store: Store(initialState: TwoCounters.State()) {
        TwoCounters()
      }
    )
  }
}
