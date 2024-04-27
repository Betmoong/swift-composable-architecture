import ComposableArchitecture
import SwiftUI

private let readMe = """
  이 화면은 일부 선택적인 자식 상태의 존재 여부에 따라 뷰를 표시하고 숨기는 방법을 보여줍니다.

  부모 상태는 `Counter.State?` 값을 가집니다. 이 값이 `nil`일 경우 기본 텍스트 뷰를 표시합니다. \
  하지만 `nil`이 아닐 경우에는 선택적이지 않은 카운터 상태에서 작동하는 카운터의 뷰 조각을 표시합니다.

  "Toggle counter state"를 탭하면 `nil`과 `nil`이 아닌 카운터 상태 사이를 전환합니다.
  """

@Reducer
struct OptionalBasics {
  @ObservableState
  struct State: Equatable {
    var optionalCounter: Counter.State?
  }

  enum Action {
    case optionalCounter(Counter.Action)
    case toggleCounterButtonTapped
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .toggleCounterButtonTapped:
        state.optionalCounter =
          state.optionalCounter == nil
          ? Counter.State()
          : nil
        return .none
      case .optionalCounter:
        return .none
      }
    }
    .ifLet(\.optionalCounter, action: \.optionalCounter) {
      Counter()
    }
  }
}

struct OptionalBasicsView: View {
  let store: StoreOf<OptionalBasics>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      Button("Toggle counter state") {
        store.send(.toggleCounterButtonTapped)
      }

      if let store = store.scope(state: \.optionalCounter, action: \.optionalCounter) {
        Text(template: "`Counter.State` is non-`nil`")
        CounterView(store: store)
          .buttonStyle(.borderless)
          .frame(maxWidth: .infinity)
      } else {
        Text(template: "`Counter.State` is `nil`")
      }
    }
    .navigationTitle("Optional state")
  }
}

#Preview {
  NavigationStack {
    OptionalBasicsView(
      store: Store(initialState: OptionalBasics.State()) {
        OptionalBasics()
      }
    )
  }
}

#Preview("Deep-linked") {
  NavigationStack {
    OptionalBasicsView(
      store: Store(
        initialState: OptionalBasics.State(
          optionalCounter: Counter.State(
            count: 42
          )
        )
      ) {
        OptionalBasics()
      }
    )
  }
}
