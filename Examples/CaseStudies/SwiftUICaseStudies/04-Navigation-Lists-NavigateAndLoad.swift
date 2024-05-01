import ComposableArchitecture
import SwiftUI

private let readMe = """
  이 화면은 목록 요소에서 선택적 상태를 로드하는 데 따른 내비게이션을 보여줍니다.

  행을 탭하면 해당 카운터 상태에 따라 의존하는 화면으로 동시에 내비게이션하고, \
  1초 후에 이 상태를 로드할 효과를 발생시킵니다.
  """

@Reducer
struct NavigateAndLoadList {
  struct State: Equatable {
    var rows: IdentifiedArrayOf<Row> = [
      Row(count: 1, id: UUID()),
      Row(count: 42, id: UUID()),
      Row(count: 100, id: UUID()),
    ]
    var selection: Identified<Row.ID, Counter.State?>?

    struct Row: Equatable, Identifiable {
      var count: Int
      let id: UUID
    }
  }

  enum Action {
    case counter(Counter.Action)
    case setNavigation(selection: UUID?)
    case setNavigationSelectionDelayCompleted
  }

  @Dependency(\.continuousClock) var clock
  private enum CancelID { case load }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .counter:
        return .none

      case let .setNavigation(selection: .some(id)):
        state.selection = Identified(nil, id: id)
        return .run { send in
          try await self.clock.sleep(for: .seconds(1))
          await send(.setNavigationSelectionDelayCompleted)
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)

      case .setNavigation(selection: .none):
        if let selection = state.selection, let count = selection.value?.count {
          state.rows[id: selection.id]?.count = count
        }
        state.selection = nil
        return .cancel(id: CancelID.load)

      case .setNavigationSelectionDelayCompleted:
        guard let id = state.selection?.id else { return .none }
        state.selection?.value = Counter.State(count: state.rows[id: id]?.count ?? 0)
        return .none
      }
    }
    .ifLet(\.selection, action: \.counter) {
      EmptyReducer()
        .ifLet(\.value, action: \.self) {
          Counter()
        }
    }
  }
}

struct NavigateAndLoadListView: View {
  @Bindable var store: StoreOf<NavigateAndLoadList>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }
        ForEach(viewStore.rows) { row in
          NavigationLink(
            "Load optional counter that starts from \(row.count)",
            tag: row.id,
            selection: viewStore.binding(
              get: \.selection?.id,
              send: { .setNavigation(selection: $0) }
            )
          ) {
            IfLetStore(self.store.scope(state: \.selection?.value, action: \.counter)) {
              CounterView(store: $0)
            } else: {
              ProgressView()
            }
          }
        }
      }
    }
    .navigationTitle("Navigate and load")
  }
}

#Preview {
  NavigationView {
    NavigateAndLoadListView(
      store: Store(
        initialState: NavigateAndLoadList.State(
          rows: [
            NavigateAndLoadList.State.Row(count: 1, id: UUID()),
            NavigateAndLoadList.State.Row(count: 42, id: UUID()),
            NavigateAndLoadList.State.Row(count: 100, id: UUID()),
          ]
        )
      ) {
        NavigateAndLoadList()
      }
    )
  }
  .navigationViewStyle(.stack)
}
