import ComposableArchitecture
import SwiftUI

private let readMe = """
  이 화면은 상태에 선택적 데이터를 로드하는 것에 따른 내비게이션을 보여줍니다.

  "Load optional counter"를 탭하면 1초 후에 카운터 상태를 로드할 효과가 발동됩니다. \
  카운터 상태가 존재하면, 이 데이터에 의존하는 시트가 프로그래밍적으로 표시됩니다.
  """

@Reducer
struct LoadThenPresent {
  @ObservableState
  struct State: Equatable {
    @Presents var counter: Counter.State?
    var isActivityIndicatorVisible = false
  }

  enum Action {
    case counter(PresentationAction<Counter.Action>)
    case counterButtonTapped
    case counterPresentationDelayCompleted
  }

  @Dependency(\.continuousClock) var clock

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .counter:
        return .none

      case .counterButtonTapped:
        state.isActivityIndicatorVisible = true
        return .run { send in
          try await self.clock.sleep(for: .seconds(1))
          await send(.counterPresentationDelayCompleted)
        }

      case .counterPresentationDelayCompleted:
        state.isActivityIndicatorVisible = false
        state.counter = Counter.State()
        return .none

      }
    }
    .ifLet(\.$counter, action: \.counter) {
      Counter()
    }
  }
}

struct LoadThenPresentView: View {
  @Bindable var store: StoreOf<LoadThenPresent>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }
      Button {
        store.send(.counterButtonTapped)
      } label: {
        HStack {
          Text("Load optional counter")
          if store.isActivityIndicatorVisible {
            Spacer()
            ProgressView()
          }
        }
      }
    }
    .sheet(item: $store.scope(state: \.counter, action: \.counter)) { store in
      CounterView(store: store)
    }
    .navigationTitle("Load and present")
  }
}

#Preview {
  NavigationStack {
    LoadThenPresentView(
      store: Store(initialState: LoadThenPresent.State()) {
        LoadThenPresent()
      }
    )
  }
}
