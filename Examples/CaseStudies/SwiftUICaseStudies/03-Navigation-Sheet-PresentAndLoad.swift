import ComposableArchitecture
import SwiftUI

private let readMe = """
  이 화면은 상태에 선택적 데이터를 로드하는 것에 따른 내비게이션을 보여줍니다.

  "Load optional counter"를 탭하면 선택적 카운터 상태에 의존하는 시트가 동시에 표시되며, 1초 후에 이 상태를 로드할 효과가 발동됩니다.
  """

@Reducer
struct PresentAndLoad {
  @ObservableState
  struct State: Equatable {
    var optionalCounter: Counter.State?
    var isSheetPresented = false
  }

  enum Action {
    case optionalCounter(Counter.Action)
    case setSheet(isPresented: Bool)
    case setSheetIsPresentedDelayCompleted
  }

  @Dependency(\.continuousClock) var clock
  private enum CancelID { case load }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .setSheet(isPresented: true):
        state.isSheetPresented = true
        return .run { send in
          try await self.clock.sleep(for: .seconds(1))
          await send(.setSheetIsPresentedDelayCompleted)
        }
        .cancellable(id: CancelID.load)

      case .setSheet(isPresented: false):
        state.isSheetPresented = false
        state.optionalCounter = nil
        return .cancel(id: CancelID.load)

      case .setSheetIsPresentedDelayCompleted:
        state.optionalCounter = Counter.State()
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

struct PresentAndLoadView: View {
  @Bindable var store: StoreOf<PresentAndLoad>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }
      Button("Load optional counter") {
        store.send(.setSheet(isPresented: true))
      }
    }
    .sheet(isPresented: $store.isSheetPresented.sending(\.setSheet)) {
      if let store = store.scope(state: \.optionalCounter, action: \.optionalCounter) {
        CounterView(store: store)
      } else {
        ProgressView()
      }
    }
    .navigationTitle("Present and load")
  }
}

#Preview {
  NavigationView {
    PresentAndLoadView(
      store: Store(initialState: PresentAndLoad.State()) {
        PresentAndLoad()
      }
    )
  }
}
